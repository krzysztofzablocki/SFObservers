//
//  Created by krzysztof.zablocki on 3/23/12.
//
//
//

#import "NSNotificationCenter+SFObservers.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSString const *NSNotificationCenterSFObserversArrayKey = @"NSNotificationCenterSFObserversArrayKey";
static NSString const *NSNotificationCenterSFObserversAllowMethodForwardingKey = @"NSNotificationCenterSFObserversAllowMethodForwardingKey";

static NSString *NSNotificationCenterSFObserversAddSelector = @"sf_original_addObserver:selector:name:object:";
static NSString *NSNotificationCenterSFObserversRemoveSelector = @"sf_original_removeObserver:";
static NSString *NSNotificationCenterSFObserversRemoveSpecificSelector = @"sf_original_removeObserver:name:object:";

@interface __SFObserversNotificationObserverInfo : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, AH_WEAK) id object;
@property(nonatomic, assign) void *blockKey;
@end

@implementation __SFObserversNotificationObserverInfo
@synthesize name;
@synthesize object;
@synthesize blockKey;


- (void)dealloc
{
  AH_RELEASE(name);
  AH_SUPER_DEALLOC;
}

@end

@implementation NSNotificationCenter (SFObservers)

+ (void)sf_swapSelector:(SEL)aOriginalSelector withSelector:(SEL)aSwappedSelector
{
  Method originalMethod = class_getInstanceMethod(self, aOriginalSelector);
  Method swappedMethod = class_getInstanceMethod(self, aSwappedSelector);

  SEL newSelector = NSSelectorFromString([NSString stringWithFormat:@"sf_original_%@", NSStringFromSelector(aOriginalSelector)]);
  class_addMethod([self class], newSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
  class_replaceMethod([self class], aOriginalSelector, method_getImplementation(swappedMethod), method_getTypeEncoding(swappedMethod));
}

+ (void)load
{
  //! swap methods
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    @autoreleasepool {
      [NSNotificationCenter sf_swapSelector:@selector(addObserver:selector:name:object:) withSelector:@selector(sf_addObserver:selector:name:object:)];
      [NSNotificationCenter sf_swapSelector:@selector(removeObserver:) withSelector:@selector(sf_removeObserver:)];
      [NSNotificationCenter sf_swapSelector:@selector(removeObserver:name:object:) withSelector:@selector(sf_removeObserver:name:object:)];
    }
  });
}

- (BOOL)allowMethodForwarding
{
  NSNumber *state = objc_getAssociatedObject(self, AH_BRIDGE(NSNotificationCenterSFObserversAllowMethodForwardingKey));
  return [state boolValue];
}

- (void)setAllowMethodForwarding:(BOOL)allowForwarding
{
  objc_setAssociatedObject(self, AH_BRIDGE(NSNotificationCenterSFObserversAllowMethodForwardingKey), [NSNumber numberWithBool:allowForwarding], OBJC_ASSOCIATION_RETAIN);
}

- (void)sf_addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName object:(id)anObject
{
  //! store info into our observer structure
  NSMutableDictionary *registeredNotifications = (NSMutableDictionary *)objc_getAssociatedObject(observer, AH_BRIDGE(NSNotificationCenterSFObserversArrayKey));
  if (!registeredNotifications) {
    registeredNotifications = [NSMutableDictionary dictionary];
    objc_setAssociatedObject(observer, AH_BRIDGE(NSNotificationCenterSFObserversArrayKey), registeredNotifications, OBJC_ASSOCIATION_RETAIN);
  }

  NSMutableArray *observerInfos = [registeredNotifications objectForKey:NSStringFromSelector(aSelector)];
  if (!observerInfos) {
    observerInfos = [NSMutableArray array];
    [registeredNotifications setObject:observerInfos forKey:NSStringFromSelector(aSelector)];
  }
  __block __SFObserversNotificationObserverInfo *observerInfo = nil;

#if !SF_OBSERVERS_ALLOW_MULTIPLE_REGISTRATIONS
  //! don't allow to add many times the same observer
  [observerInfos enumerateObjectsUsingBlock:^void(id obj, NSUInteger idx, BOOL *stop) {
    __SFObserversNotificationObserverInfo *info = obj;
    if ([info.name isEqualToString:aName] && info.object == anObject) {
      observerInfo = info;
      *stop = YES;
    }
  }];

  if (!observerInfo) {
    observerInfo = [[__SFObserversNotificationObserverInfo alloc] init];
    [observerInfos addObject:observerInfo];
    AH_RELEASE(observerInfo);
  } else {
    //! don't register twice so skip this
    NSAssert(NO, @"You shouldn't register twice for same notification, selector, name, object");
    return;
  }
#else
  observerInfo = [[__SFObserversNotificationObserverInfo alloc] init];
  [observerInfos addObject:observerInfo];
  AH_RELEASE(observerInfo);
#endif

  observerInfo.name = aName;
  observerInfo.object = anObject;

  //! Add auto remove when observer is going to be deallocated
  __AH_WEAK __block id weakSelf = self;
  __AH_WEAK __block id weakObject = anObject;

  void *key = [observer performBlockOnDealloc:^(id obj){
    id strongObserver = obj;
    int numberOfRemovals = 0;
    if ((numberOfRemovals = [weakSelf sf_removeObserver:strongObserver name:aName object:weakObject registeredNotifications:registeredNotifications])) {
      for (int i = 0; i < numberOfRemovals; ++i) {
        [weakSelf setAllowMethodForwarding:YES];
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
        NSLog(@"Calling original method %@ with parameters %@ %@ %@", NSNotificationCenterSFObserversRemoveSpecificSelector, strongObserver, aName, weakObject);
#endif
        objc_msgSend(weakSelf, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSpecificSelector), strongObserver, aName, weakObject);
        [weakSelf setAllowMethodForwarding:NO];
      }
    }
  }];

  //! remember the block key
  observerInfo.blockKey = key;

  //! call originalMethod
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
  NSLog(@"Calling original method %@ with parameters %@ %@ %@ %@", NSNotificationCenterSFObserversAddSelector, observer, NSStringFromSelector(aSelector), aName, anObject);
#endif
  objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversAddSelector), observer, aSelector, aName, anObject);
}


- (void)sf_removeObserver:(id)observer
{
  if ([self allowMethodForwarding]) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
    NSLog(@"Calling original method %@ with parameters %@", NSNotificationCenterSFObserversRemoveSelector, observer);
#endif
    objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSelector), observer);
    return;
  }

  NSMutableDictionary *registeredNotifications = (NSMutableDictionary *)objc_getAssociatedObject(observer, AH_BRIDGE(NSNotificationCenterSFObserversArrayKey));
  int numberOfRemovals = 0;
  if ((numberOfRemovals = [self sf_removeObserver:observer name:nil object:nil registeredNotifications:registeredNotifications])) {
    for (int i = 0; i < numberOfRemovals; ++i) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
      NSLog(@"Calling original method %@ with parameters %@", NSNotificationCenterSFObserversRemoveSelector, observer);
#endif
      [self setAllowMethodForwarding:YES];
      objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSelector), observer);
      [self setAllowMethodForwarding:NO];
    }
  }

}

- (void)sf_removeObserver:(id)observer name:(NSString *)aName object:(id)anObject
{
  if ([self allowMethodForwarding]) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
    NSLog(@"Calling original method %@ with parameters %@ %@ %@", NSNotificationCenterSFObserversRemoveSpecificSelector, observer, aName, anObject);
#endif
    objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSpecificSelector), observer, aName, anObject);
    return;
  }

  NSMutableDictionary *registeredNotifications = (NSMutableDictionary *)objc_getAssociatedObject(observer, AH_BRIDGE(NSNotificationCenterSFObserversArrayKey));
  int numberOfRemovals = 0;
  if ([self allowMethodForwarding] || (numberOfRemovals = [self sf_removeObserver:observer name:aName object:anObject registeredNotifications:registeredNotifications])) {
    [self setAllowMethodForwarding:YES];
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
    NSLog(@"Calling original method %@ with parameters %@ %@ %@", NSNotificationCenterSFObserversRemoveSpecificSelector, observer, aName, anObject);
#endif
    objc_msgSend(self, NSSelectorFromString(NSNotificationCenterSFObserversRemoveSpecificSelector), observer, aName, anObject);
    [self setAllowMethodForwarding:NO];
  }

}

- (NSUInteger)sf_removeObserver:(id)observer name:(NSString *)aName object:(id)anObject registeredNotifications:(NSMutableDictionary *)registeredNotifications
{
  __block NSUInteger result = 0;

  if (aName == nil && anObject == nil) {
    //! don't need to execute block on dealloc so cleanup
    [registeredNotifications enumerateKeysAndObjectsUsingBlock:^void(id key, id obj, BOOL *stop) {
      NSMutableArray *observerInfos = obj;
      [observerInfos enumerateObjectsUsingBlock:^void(id innerObj, NSUInteger idx, BOOL *innerStop) {
        __SFObserversNotificationObserverInfo *info = innerObj;
        [observer cancelDeallocBlockWithKey:info.blockKey];
      }];
    }];
    [registeredNotifications removeAllObjects];

    return 1;
  } else {
    [registeredNotifications enumerateKeysAndObjectsUsingBlock:^void(id key, id obj, BOOL *stop) {
      NSMutableArray *observerInfos = obj;
      NSMutableArray *objectsToRemove = [NSMutableArray array];
      [observerInfos enumerateObjectsUsingBlock:^void(id innerObj, NSUInteger idx, BOOL *innerStop) {
        __SFObserversNotificationObserverInfo *info = innerObj;

        if ((!aName || [aName isEqualToString:info.name]) && (!anObject || (anObject == info.object))) {
          //! remove this info
          [objectsToRemove addObject:innerObj];

          //! cancel dealloc blocks
          [observer cancelDeallocBlockWithKey:info.blockKey];
        }
      }];

      //! remove all collected objects
      if ([objectsToRemove count] > 0) {
#if SF_OBSERVERS_ALLOW_MULTIPLE_REGISTRATIONS
        result = [objectsToRemove count];
#else
        result = 1;
        #endif
        [observerInfos removeObjectsInArray:objectsToRemove];
      }
    }];
  }

  return result;
}
@end
