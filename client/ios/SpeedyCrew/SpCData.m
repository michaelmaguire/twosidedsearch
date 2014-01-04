//
//  SpCData.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 30/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCData.h"
#import "SpcDatabase.h"

@implementation SpCData

- (SpCData*)init
{
    SpCDatabase* database = [SpCDatabase database];
    self.identity = [database querySetting: @"scid"];
    self.searches = [[NSMutableArray alloc] init]; //-dk:TODO recover stored searches
    return self;
}

@end
