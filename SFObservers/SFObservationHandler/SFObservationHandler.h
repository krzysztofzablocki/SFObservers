//
//  Created by merowing on 16/07/13.
//
//
//


#import <Foundation/Foundation.h>


@interface SFObservationHandler : NSObject
+ (SFObservationHandler *)sharedInstance;

- (void)addObserver:(id)observer forObject:(NSObject *)object keyPath:(NSString *)path option:(NSKeyValueObservingOptions)option context:(void *)context;

- (void)removeObserver:(id)observer forObject:(NSObject *)object keyPath:(NSString *)path context:(void *)context;

- (void)removeObserver:(id)observer forObject:(NSObject *)object keyPath:(NSString *)path;

@end