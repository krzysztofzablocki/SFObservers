//
//  Created by merowing2 on 3/25/12.
//
//
//
#import <objc/runtime.h>
#import <objc/message.h>
#import "NSObject+SFObservers.h"
#import "SFObservationHandler.h"

static NSString *NSObjectKVOSFObserversAddSelector = @"sf_original_addObserver:forKeyPath:options:context:";
static NSString *NSObjectKVOSFObserversRemoveSelector = @"sf_original_removeObserver:forKeyPath:";
static NSString *NSObjectKVOSFObserversRemoveSpecificSelector = @"sf_original_removeObserver:forKeyPath:context:";


static NSString const *NSObjectKVOSFObserversArrayKey = @"NSObjectKVOSFObserversArrayKey";
static NSString const *NSObjectKVOSFObserversAllowMethodForwardingKey = @"NSObjectKVOSFObserversAllowMethodForwardingKey";

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

- (BOOL)sf_useOriginalMethods
{
  NSNumber *state = objc_getAssociatedObject(self, AH_BRIDGE(NSObjectKVOSFObserversAllowMethodForwardingKey));
  return [state boolValue];
}

- (void)setSf_useOriginalMethods:(BOOL)allowForwarding
{
  objc_setAssociatedObject(self, AH_BRIDGE(NSObjectKVOSFObserversAllowMethodForwardingKey), [NSNumber numberWithBool:allowForwarding], OBJC_ASSOCIATION_RETAIN);
}

- (void)sf_addObserver:(id)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)aContext
{
  [[SFObservationHandler sharedInstance] addObserver:observer forObject:self keyPath:keyPath option:options context:aContext];

  //! call original method
  objc_msgSend(self, NSSelectorFromString(NSObjectKVOSFObserversAddSelector), observer, keyPath, options, aContext);
}


- (void)sf_removeObserver:(id)observer forKeyPath:(NSString *)keyPath
{
  if (![self sf_useOriginalMethods]) {
    [[SFObservationHandler sharedInstance] removeObserver:observer forObject:self keyPath:keyPath];
  }

  self.sf_useOriginalMethods = YES;
  objc_msgSend(self, NSSelectorFromString(NSObjectKVOSFObserversRemoveSelector), observer, keyPath);
  self.sf_useOriginalMethods = NO;
}

- (void)sf_removeObserver:(id)observer forKeyPath:(NSString *)keyPath context:(void *)context
{
  if (![self sf_useOriginalMethods]) {
    [[SFObservationHandler sharedInstance] removeObserver:observer forObject:self keyPath:keyPath context:context];
  }

  self.sf_useOriginalMethods = YES;
  objc_msgSend(self, NSSelectorFromString(NSObjectKVOSFObserversRemoveSpecificSelector), observer, keyPath, context);
  self.sf_useOriginalMethods = NO;
}
@end
