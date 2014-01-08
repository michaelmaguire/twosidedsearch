//
//  SpCSearch.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 01/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpCSearch : NSObject

@property (readonly) NSString* name;
@property (readonly) NSString* query;
@property (readonly) NSString* id;

@property NSMutableArray* results;

- (SpCSearch*)init;
- (void)updateQueryWith:(NSString*)query;
- (void)addListener:(NSObject*)listener withId:(NSString*)id;
- (void)removeListenerWithId:(NSString*)id;

@end
