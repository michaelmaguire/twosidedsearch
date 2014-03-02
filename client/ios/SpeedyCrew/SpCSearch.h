//
//  SpCSearch.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 01/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SpCChanging.h"

@interface SpCSearch : SpCChanging

@property (readonly) NSString* name;
@property (readonly) NSString* query;
@property (readonly) NSString* id;
@property (readonly) NSString* side;

@property NSMutableArray* results;

- (SpCSearch*)init;
- (SpCSearch*)initWithDictionary:(NSDictionary*)dict;
- (void)updateQueryWith:(NSString*)query;
- (NSString*) encodeURL: (NSString*) str; // this should life in some better place...

@end
