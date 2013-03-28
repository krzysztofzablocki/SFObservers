//
//  Created by merowing2 on 3/25/12.
//
//
//
#import <objc/runtime.h>
#import <objc/message.h>
#import "NSObject+SFObservers.h"

static NSString const *NSObjectKVOSFObserversArrayKey = @"NSObjectKVOSFObserversArrayKey";
static NSString const *NSObjectKVOSFObserversAllowMethodForwardingKey = @"NSObjectKVOSFObserversAllowMethodForwardingKey";

static NSString *NSObjectKVOSFObserversAddSelector = @"sf_original_addObserver:forKeyPath:options:context:";
static NSString *NSObjectKVOSFObserversRemoveSelector = @"sf_original_removeObserver:forKeyPath:";
static NSString *NSObjectKVOSFObserversRemoveSpecificSelector = @"sf_original_removeObserver:forKeyPath:context:";

@interface __SFObserversKVOObserverInfo : NSObject
@property(nonatomic, copy) NSString *keyPath;
@property(nonatomic, assign) void *context;
@property(nonatomic, assign) void *blockKey;
@end

@implementation __SFObserversKVOObserverInfo
@synthesize keyPath;
@synthesize context;
@synthesize blockKey;

- (void)dealloc
{
  AH_RELEASE(keyPath);
  AH_SUPER_DEALLOC;
}

@end


@implementation NSObject (SFObservers)

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
      [NSObject sf_swapSelector:@selector(addObserver:forKeyPath:options:context:) withSelector:@selector(sf_addObserver:forKeyPath:options:context:)];
      [NSObject sf_swapSelector:@selector(removeObserver:forKeyPath:) withSelector:@selector(sf_removeObserver:forKeyPath:)];
      [NSObject sf_swapSelector:@selector(removeObserver:forKeyPath:context:) withSelector:@selector(sf_removeObserver:forKeyPath:context:)];
    }
  });
}

- (BOOL)allowMethodForwarding
{
  NSNumber *state = objc_getAssociatedObject(self, AH_BRIDGE(NSObjectKVOSFObserversAllowMethodForwardingKey));
  return [state boolValue];
}

- (void)setAllowMethodForwarding:(BOOL)allowForwarding
{
  objc_setAssociatedObject(self, AH_BRIDGE(NSObjectKVOSFObserversAllowMethodForwardingKey), [NSNumber numberWithBool:allowForwarding], OBJC_ASSOCIATION_RETAIN);
}

- (void)sf_addObserver:(id)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)aContext
{
  //! store info into our observer structure
  NSMutableDictionary *registeredKeyPaths = (NSMutableDictionary *)objc_getAssociatedObject(observer, AH_BRIDGE(NSObjectKVOSFObserversArrayKey));
  if (!registeredKeyPaths) {
    registeredKeyPaths = [NSMutableDictionary dictionary];
    objc_setAssociatedObject(observer, AH_BRIDGE(NSObjectKVOSFObserversArrayKey), registeredKeyPaths, OBJC_ASSOCIATION_RETAIN);
  }

  NSMutableArray *observerInfos = [registeredKeyPaths objectForKey:keyPath];
  if (!observerInfos) {
    observerInfos = [NSMutableArray array];
    [registeredKeyPaths setObject:observerInfos forKey:keyPath];
  }
  __block __SFObserversKVOObserverInfo *observerInfo = nil;

#if !SF_OBSERVERS_ALLOW_MULTIPLE_REGISTRATIONS
  //! don't allow to add many times the same observer
  [observerInfos enumerateObjectsUsingBlock:^void(id obj, NSUInteger idx, BOOL *stop) {
    __SFObserversKVOObserverInfo *info = obj;
    if ([info.keyPath isEqualToString:keyPath] && info.context == aContext) {
      observerInfo = info;
      *stop = YES;
    }
  }];

  if (!observerInfo) {
    observerInfo = [[__SFObserversKVOObserverInfo alloc] init];
    [observerInfos addObject:observerInfo];
    AH_RELEASE(observerInfo);
  } else {
    //! don't register twice so skip this
    NSAssert(NO, @"You shouldn't register twice for same keyPath, context");
    return;
  }
#else
  observerInfo = [[__SFObserversKVOObserverInfo alloc] init];
  [observerInfos addObject:observerInfo];
  AH_RELEASE(observerInfo);
#endif

  observerInfo.keyPath = keyPath;
  observerInfo.context = aContext;

  //! Add auto remove when observer is going to be deallocated
  __AH_WEAK __block id weakSelf = self;

  void *key = [observer performBlockOnDealloc:^(id obj){
    id strongObserver = obj;
    int numberOfRemovals = 0;
    if ((numberOfRemovals = [weakSelf sf_removeObserver:strongObserver forKeyPath:keyPath context:aContext registeredKeyPaths:registeredKeyPaths])) {
      for (int i = 0; i < numberOfRemovals; ++i) {
        [weakSelf setAllowMethodForwarding:YES];
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
        NSLog(@"Calling original method %@ with parameters %@ %@ %p", NSObjectKVOSFObserversRemoveSpecificSelector, strongObserver, keyPath, aContext);
#endif
        objc_msgSend(weakSelf, NSSelectorFromString(NSObjectKVOSFObserversRemoveSpecificSelector), strongObserver, keyPath, aContext);
        [weakSelf setAllowMethodForwarding:NO];
      }
    }
  }];

  observerInfo.blockKey = key;

  //! call originalMethod
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
  NSLog(@"Calling original method %@ with parameters %@ %@ %d %p", NSObjectKVOSFObserversAddSelector, observer, keyPath, options, aContext);
#endif
  objc_msgSend(self, NSSelectorFromString(NSObjectKVOSFObserversAddSelector), observer, keyPath, options, aContext);
}


- (void)sf_removeObserver:(id)observer forKeyPath:(NSString *)keyPath
{
  if ([self allowMethodForwarding]) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
    NSLog(@"Calling original method %@ with parameters %@ %@", NSObjectKVOSFObserversRemoveSelector, observer, keyPath);
#endif
    objc_msgSend(self, NSSelectorFromString(NSObjectKVOSFObserversRemoveSelector), observer, keyPath);
    return;
  }

  NSMutableDictionary *registeredKeyPaths = (NSMutableDictionary *)objc_getAssociatedObject(observer, AH_BRIDGE(NSObjectKVOSFObserversArrayKey));
  int numberOfRemovals = 0;
  if ((numberOfRemovals = [self sf_removeObserver:observer forKeyPath:keyPath context:nil registeredKeyPaths:registeredKeyPaths])) {
    for (int i = 0; i < numberOfRemovals; ++i) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
      NSLog(@"Calling original method %@ with parameters %@ %@", NSObjectKVOSFObserversRemoveSelector, observer, keyPath);
#endif
      [self setAllowMethodForwarding:YES];
      objc_msgSend(self, NSSelectorFromString(NSObjectKVOSFObserversRemoveSelector), observer, keyPath);
      [self setAllowMethodForwarding:NO];
    }
  }
}

- (void)sf_removeObserver:(id)observer forKeyPath:(NSString *)keyPath context:(void *)context
{
  if ([self allowMethodForwarding]) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
    NSLog(@"Calling original method %@ with parameters %@ %@ %p", NSObjectKVOSFObserversRemoveSpecificSelector, observer, keyPath, context);
#endif
    objc_msgSend(self, NSSelectorFromString(NSObjectKVOSFObserversRemoveSpecificSelector), observer, keyPath, context);
    return;
  }

  NSMutableDictionary *registeredKeyPaths = (NSMutableDictionary *)objc_getAssociatedObject(observer, AH_BRIDGE(NSObjectKVOSFObserversArrayKey));
  int numberOfRemovals = 0;
  if ([self allowMethodForwarding] || (numberOfRemovals = [self sf_removeObserver:observer forKeyPath:keyPath context:context registeredKeyPaths:registeredKeyPaths])) {
    for (int i = 0; i < numberOfRemovals; ++i) {
#if SF_OBSERVERS_LOG_ORIGINAL_METHODS
      NSLog(@"Calling original method %@ with parameters %@ %@ %p", NSObjectKVOSFObserversRemoveSpecificSelector, observer, keyPath, context);
#endif
      [self setAllowMethodForwarding:YES];
      objc_msgSend(self, NSSelectorFromString(NSObjectKVOSFObserversRemoveSpecificSelector), observer, keyPath, context);
      [self setAllowMethodForwarding:NO];
    }
  }

}

- (NSUInteger)sf_removeObserver:(id)observer
                     forKeyPath:(NSString *)keyPath
                        context:(void *)context
             registeredKeyPaths:(NSMutableDictionary *)registeredKeyPaths
{
  __block NSUInteger result = 0;
  if ([keyPath length] <= 0 && context == nil) {
    //! don't need to execute block on dealloc so cleanup
    [registeredKeyPaths enumerateKeysAndObjectsUsingBlock:^void(id key, id obj, BOOL *stop) {
      NSMutableArray *observerInfos = obj;
      [observerInfos enumerateObjectsUsingBlock:^void(id innerObj, NSUInteger idx, BOOL *innerStop) {
        __SFObserversKVOObserverInfo *info = innerObj;
        [observer cancelDeallocBlockWithKey:info.blockKey];
      }];
    }];
    [registeredKeyPaths removeAllObjects];
    return 1;
  } else {
    [registeredKeyPaths enumerateKeysAndObjectsUsingBlock:^void(id key, id obj, BOOL *stop) {
      NSMutableArray *observerInfos = obj;
      NSMutableArray *objectsToRemove = [NSMutableArray array];
      [observerInfos enumerateObjectsUsingBlock:^void(id innerObj, NSUInteger idx, BOOL *innerStop) {
        __SFObserversKVOObserverInfo *info = innerObj;

        if ((!keyPath || [keyPath isEqualToString:info.keyPath]) && (context == info.context)) {
          //! remove this info
          [objectsToRemove addObject:innerObj];

          //! cancel dealloc block
          [observer cancelDeallocBlockWithKey:info.blockKey];
        }
      }];

      //! remove all collected objects
      if ([objectsToRemove count] > 0) {
        //! multiple registrations should match unregistrations
#if SF_OBSERVERS_ALLOW_MULTIPLE_REGISTRATIONS
        result = [objectsToRemove count];
#else
        result  = 1;
#endif
        [observerInfos removeObjectsInArray:objectsToRemove];
      }
    }];
  }

  return result;
}
@end
