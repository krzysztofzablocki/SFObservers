//
//  NSObject+SFExecuteOnDealloc.h
//  SampleProject
//
//  Created by Krzysztof Zabłocki on 2/28/12.
//  Copyright (c) 2012 Krzysztof Zabłocki. All rights reserved.
//

//  ARC Helper
//
//  Version 1.2.2
//
//  Created by Nick Lockwood on 05/01/2012.
//  Copyright 2012 Charcoal Design
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://gist.github.com/1563325

//  Krzysztof Zabłocki Added AH_BRIDGE(x) to bridge cast to void*
#ifndef AH_RETAIN
#if __has_feature(objc_arc)
#define AH_RETAIN(x) (x)
#define AH_RELEASE(x) (void)(x)
#define AH_AUTORELEASE(x) (x)
#define AH_SUPER_DEALLOC (void)(0)
#define AH_BRIDGE(x) ((__bridge void*)x)
#else
#define __AH_WEAK
#define AH_WEAK assign
#define AH_RETAIN(x) [(x) retain]
#define AH_RELEASE(x) [(x) release]
#define AH_AUTORELEASE(x) [(x) autorelease]
#define AH_SUPER_DEALLOC [super dealloc]
#define AH_BRIDGE(x) (x)
#endif
#endif

//  Weak reference support

#ifndef AH_WEAK
#if defined __IPHONE_OS_VERSION_MIN_REQUIRED
#if __IPHONE_OS_VERSION_MIN_REQUIRED > __IPHONE_4_3
#define __AH_WEAK __weak
#define AH_WEAK weak
#else
#define __AH_WEAK __unsafe_unretained
#define AH_WEAK unsafe_unretained
#endif
#elif defined __MAC_OS_X_VERSION_MIN_REQUIRED
#if __MAC_OS_X_VERSION_MIN_REQUIRED > __MAC_10_6
#define __AH_WEAK __weak
#define AH_WEAK weak
#else
#define __AH_WEAK __unsafe_unretained
#define AH_WEAK unsafe_unretained
#endif
#endif
#endif

#import <Foundation/Foundation.h>


#define SF_EXECUTE_ON_DEALLOC_USE_SHORTHAND 1

@interface NSObject (SFExecuteOnDealloc)
#if SF_EXECUTE_ON_DEALLOC_USE_SHORTHAND
- (void *)performBlockOnDealloc:(void(^)(void))aBlock;

- (void)cancelDeallocBlockWithKey:(void *)blockKey;
#else
- (void*)sf_performBlockOnDealloc:(void(^)(void))aBlock;
- (void)sf_cancelDeallocBlockWithKey:(void*)blockKey;
#endif
@end
