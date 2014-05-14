//
//  SpCSearchView.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 14/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearchView.h"

@interface SpCSearchView()
@property NSString* id;
@property NSString* side;
@end

@implementation SpCSearchView

+ (SpCSearchView*)makeWithId:(NSString*)id andSide:(NSString*)side
{
    NSLog(@"makeWithId: %@ %@", id, side);
    return [[SpCSearchView alloc] initWithId:id andSide:side];
}

- (SpCSearchView*)initWithId:(NSString*)id andSide:(NSString*)side
{
    self = [super init];
    self.id       = id;
    self.side     = side;
    self.expanded = true;
    NSLog(@"created search with id %@ (%s)", self.id, self.expanded? "expanded": "collapsed");
    return self;
}

@end
