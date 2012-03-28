//
//  NSObject+SFExecuteOnDealloc.m
//  SampleProject
//
//  Created by Krzysztof Zabłocki on 2/28/12.
//  Copyright (c) 2012 Krzysztof Zabłocki. All rights reserved.
//
#import <objc/runtime.h>
#import "NSObject+SFExecuteOnDealloc.h"
#import "SFObservers.h"

@interface SFExecuteOnDeallocInternalObject : NSObject
@property(nonatomic, copy) void (^block)();

- (id)initWithBlock:(void(^)(void))aBlock;
@end

@implementation SFExecuteOnDeallocInternalObject {

  void(^block)(void);

}
@synthesize block;


- (id)initWithBlock:(void(^)(void))aBlock
{
  self = [super init];
  if (self) {
    block = [aBlock copy];
  }
  return self;
}

- (void)dealloc
{
  if (block) {
    block();
    AH_RELEASE(block);
  }
  AH_SUPER_DEALLOC;
}
@end

@implementation NSObject (SFExecuteOnDealloc)
#if SF_EXECUTE_ON_DEALLOC_USE_SHORTHAND
- (void *)performBlockOnDealloc:(void(^)(void))aBlock
#else
- (void*)sf_performBlockOnDealloc:(void(^)(void))aBlock
#endif
{
  //! we need some object that will be deallocated with this one, and since we are only assigning and never again needing access to this object, let use its memory adress as key
  SFExecuteOnDeallocInternalObject *internalObject = [[SFExecuteOnDeallocInternalObject alloc] initWithBlock:aBlock];
  objc_setAssociatedObject(self, AH_BRIDGE(internalObject), internalObject, OBJC_ASSOCIATION_RETAIN);
  AH_RELEASE(internalObject);
  return AH_BRIDGE(internalObject);
}
#if SF_EXECUTE_ON_DEALLOC_USE_SHORTHAND
- (void)cancelDeallocBlockWithKey:(void *)blockKey
#else
- (void)sf_cancelDeallocBlockWithKey:(void*)blockKey
#endif
{
  //! first cleanup the associated block
  SFExecuteOnDeallocInternalObject *internalObject = objc_getAssociatedObject(self, blockKey);
  internalObject.block = nil;

  //! release internal object
  objc_setAssociatedObject(self, blockKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

@end
