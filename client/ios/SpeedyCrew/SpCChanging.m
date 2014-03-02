//
//  SpCChanging.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 02/03/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCChanging.h"

@interface SpCChanging()
@property NSMutableDictionary* listeners;
@end

@implementation SpCChanging


- (SpCChanging*)init;
{
    self = [super init];
    self.listeners = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)addListener:(void (^)(NSString* name, NSObject* object))listener withId:(NSString*)name;

{
    [self.listeners setObject:listener forKey:name];
}
- (void)removeListenerWithId:(NSString*)name
{
    [self.listeners removeObjectForKey:name];
}
- (void)removeAllListeners
{
    [self.listeners removeAllObjects];
}
- (void)notify
{
    [self.listeners enumerateKeysAndObjectsUsingBlock: ^(id name, id object, BOOL* stop)  {
        void(^listener)(NSString*, NSObject*) = object;
        listener(name, self);
    }];
}

@end
