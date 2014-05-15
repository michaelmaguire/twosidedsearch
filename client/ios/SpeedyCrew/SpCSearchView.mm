//
//  SpCSearchView.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 14/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearchView.h"
#import "SpCDatabase.h"
#include "Database.h"

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
    self.results  = [[NSMutableArray alloc] init];
    NSLog(@"created search with id %@ (%s)", self.id, self.expanded? "expanded": "collapsed");
    return self;
}

- (int)updateResults
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    [self.results removeAllObjects];
    std::vector<std::string> names = db->queryColumn("select name from results where search='" + db->escape([self.id UTF8String]) + "';");
    for (std::vector<std::string>::const_iterator it(names.begin()), end(names.end()); it != end; ++it) {
        [self.results addObject: [NSString stringWithFormat:@"%s", it->c_str()]];
    }
    NSLog(@"vector size=%d results size=%d", int(names.size()), [self.results count]);
    return [self.results count];
}

@end
