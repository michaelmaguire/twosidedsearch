//
//  SpCResult.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 02/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCResult.h"

@implementation SpCResult

- (SpCResult*)initWithId: (NSString*)id value: (NSString*) value
{
    self.id    = id;
    self.value = value;
    return [super init];
}

@end
