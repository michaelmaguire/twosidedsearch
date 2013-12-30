//
//  SpCData.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 30/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCData.h"

@implementation SpCData

- (SpCData*)init
{
    NSLog(@"allocating data");
    self.identity = @"dummy-identity";             //-dk:TODO recover stored identity
    self.searches = [[NSMutableArray alloc] init]; //-dk:TODO recover stored searches
    
    NSArray* s = @[@"search-1", @"search-2", @"search-3"];
    int size = [s count];
    for (int i = 0; i != size; ++i) {
        [self.searches addObject: [s objectAtIndex:i]];
    }
    return self;
}

@end
