//
//  SpCChanging.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 02/03/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpCChanging : NSObject

- (SpCChanging*)init;
- (void)addListener:(void (^)(NSString* name, NSObject* object))listener withId:(NSString*)name;
- (void)removeListenerWithId:(NSString*)name;
- (void)removeAllListeners;
- (void)notify;

@end
