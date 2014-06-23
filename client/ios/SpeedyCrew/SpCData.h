//
//  SpCData.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 30/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SpCChanging.h"
//#import "SpCSearch.h"

@interface SpCData : SpCChanging

@property NSString*       identity;
@property NSMutableArray* searches;
@property float           longitude;
@property float           latitude;

- (SpCData*)init;
- (void)synchronise;
- (void)sendToken:(NSString*)token;
- (void)updateSetting:(NSString*)name with:(NSString*)value;

- (void)addSearchWithText:(NSString*)text forSide:(NSString*)side;
- (void)deleteSearch:(NSString*)id;

@end
