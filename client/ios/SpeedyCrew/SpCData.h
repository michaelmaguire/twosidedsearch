//
//  SpCData.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 30/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SpCChanging.h"
#import "SpCSearch.h"

@interface SpCData : SpCChanging

@property NSString*       identity;
@property NSMutableArray* searches;

- (SpCData*)init;
- (void)updateSetting:(NSString*)name with:(NSString*)value;
- (void)updateSearches;
- (void)deleteSearch:(SpCSearch*)search;

@end
