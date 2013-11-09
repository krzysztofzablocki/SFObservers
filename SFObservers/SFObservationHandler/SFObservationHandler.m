//
//  Created by merowing on 16/07/13.
//
//
//


#import "SFObservationHandler.h"
#import "NSObject+SFObservers.h"

@interface SFObservationHandlerInfo : NSObject
@property(nonatomic, unsafe_unretained) id observer;
@property(nonatomic, unsafe_unretained) id object;
@property(nonatomic, copy) NSString *path;
@property(nonatomic, assign) NSKeyValueObservingOptions options;
@property(nonatomic, assign) void *context;
@property(nonatomic, copy) void (^cancelationBlock)(void *, void *);

@property(nonatomic, assign, readonly) NSUInteger sortOrder;
@property(nonatomic, assign) BOOL skipContextCompare;
@end

@implementation SFObservationHandlerInfo
- (NSUInteger)sortOrder
{
  NSUInteger value = self.object == nil ? 0 : 1;
  value += [self.path isEqualToString:@""] ? 0 : 2;
  value += (self.context == NULL) ? 0 : 2;
  value += self.options == 0 ? 0 : 2;
  return value;
}

- (BOOL)isEqual:(SFObservationHandlerInfo *)other
{
  if (other == self) {
    return YES;
  }

  if (!other || ![[other class] isEqual:[self class]]) {
    return NO;
  }

  if (self.object != other.object) {
    return NO;
  }

  if (self.observer != other.observer) {
    return NO;
  }

  if (![self.path isEqualToString:other.path]) {
    return NO;
  }

  if ((self.skipContextCompare == NO && other.skipContextCompare == NO) && self.context != other.context) {
    return NO;
  }

  return YES;
}

- (void)setCancelationBlock:(void (^)(void *, void *))cancelationBlock
{
  void *weakObserver = (__bridge void *)self.observer;
  void *weakObject = (__bridge void *)self.object;
  void (^deallocBlock)(id) = ^(id obj) {
    cancelationBlock(weakObserver, weakObject);
  };

  [self.object performBlockOnDealloc:deallocBlock];
  [self.observer performBlockOnDealloc:deallocBlock];
}

- (NSString *)description
{
  NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
  [description appendFormat:@"keyPath:%@, context: %p object: %p observer: %p>", self.path, self.context, (__bridge void *)self.object, (__bridge void*)self.observer];
  return description;
}

@end

@interface SFObservationHandler ()
@property(nonatomic, strong) NSMutableArray *observationInfos;
@end

@implementation SFObservationHandler {
}

+ (SFObservationHandler *)sharedInstance
{
  static dispatch_once_t onceToken;
  static SFObservationHandler *singleton;
  dispatch_once(&onceToken, ^{
    singleton = [[SFObservationHandler alloc] init];
  });

  return singleton;
}

- (id)init
{
  self = [super init];
  if (self) {
    self.observationInfos = [NSMutableArray new];
  }

  return self;
}

- (void)addObserver:(id)observer forObject:(NSObject *)object keyPath:(NSString *)path option:(NSKeyValueObservingOptions)option context:(void *)context
{
  // object, path, context, option
  SFObservationHandlerInfo *info = [SFObservationHandlerInfo new];
  info.observer = observer;
  info.object = object;
  info.path = path;
  info.options = option;
  info.context = context;

  __weak id weakInfo = info;
  info.cancelationBlock = ^(void *aObserver, void *aObject) {
    if ([self.observationInfos indexOfObjectIdenticalTo:weakInfo] != NSNotFound) {
      [self.observationInfos removeObjectIdenticalTo:weakInfo];

      NSObject *obj = (__bridge NSObject *)aObject;
      NSObject *observer = (__bridge NSObject *)aObserver;

      obj.sf_useOriginalMethods = YES;
      observer.sf_useOriginalMethods = YES;
      [obj removeObserver:(__bridge NSObject *)aObserver forKeyPath:path context:context];
      observer.sf_useOriginalMethods = NO;
      obj.sf_useOriginalMethods = NO;
    }
  };

  [self.observationInfos addObject:info];
}

- (void)removeObserver:(id)observer forObject:(NSObject *)object keyPath:(NSString *)path context:(void *)context
{
  SFObservationHandlerInfo *info = [SFObservationHandlerInfo new];
  info.observer = observer;
  info.object = object;
  info.path = path;
  info.context = context;

  if (context == nil) {
    info.skipContextCompare = YES;
  }
  NSUInteger index = [self.observationInfos indexOfObject:info];

  if (index != NSNotFound) {
    [self.observationInfos removeObjectAtIndex:index];
  }
}

- (void)removeObserver:(id)observer forObject:(NSObject *)object keyPath:(NSString *)path
{
  SFObservationHandlerInfo *info = [SFObservationHandlerInfo new];
  info.observer = observer;
  info.object = object;
  info.path = path;

  info.skipContextCompare = YES;
  NSUInteger index = [self.observationInfos indexOfObject:info];
  if (index != NSNotFound) {
    [self.observationInfos removeObjectAtIndex:index];
  }
  NSLog(@"Warning, Apple doesn't recommend using removeObserver:forObject:keyPath because context is missing");
}

@end