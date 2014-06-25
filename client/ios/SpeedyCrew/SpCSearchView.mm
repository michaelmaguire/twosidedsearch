//
//  SpCSearchView.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 14/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearchView.h"
#import "SpCResultView.h"
#import "SpCAppDelegate.h" //-dk:TODO remove!
#import "SpCDatabase.h"
#include "Database.h"

@interface SpCSearchView()
@property NSString* id;
@property NSString* side;
@end

@implementation SpCSearchView

+ (SpCSearchView*)makeWithId:(NSString*)id andSide:(NSString*)side
{
    return [[SpCSearchView alloc] initWithId:id andSide:side];
}

- (SpCSearchView*)initWithId:(NSString*)id andSide:(NSString*)side
{
    self = [super init];
    self.id       = id;
    self.side     = side;
    self.expanded = true;
    self.results  = [[NSMutableArray alloc] init];
    return self;
}

- (int)updateResults
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    //-dk:TODO splice the current and the new objects together to retain
    //   state and possibly position
    [self.results removeAllObjects];
    std::vector<std::string> names = db->queryColumn("select id from match where search='" + db->escape([self.id UTF8String]) + "';");
    for (std::vector<std::string>::const_iterator it(names.begin()), end(names.end()); it != end; ++it) {
        [self.results addObject: [SpCResultView makeWithId:[NSString stringWithFormat:@"%s", it->c_str()]]];
    }
    return int([self.results count]);
}

// ----------------------------------------------------------------------------

- (CLLocationCoordinate2D)getPosition
{
    CLLocationCoordinate2D rc = {};
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string id = [self.id UTF8String];
    rc.latitude  = db->query<double>("select latitude from search where id='" + id + "'");
    rc.longitude = db->query<double>("select longitude from search where id='" + id + "'");
    return rc;
}

// ----------------------------------------------------------------------------
// Annotation functions

- (CLLocationCoordinate2D)coordinate
{
    return [self getPosition];
}

- (void)setCoordinate:(CLLocationCoordinate2D)position
{
#if 0
    //-dk:TODO update the search position rather than just setting data!
#else
    SpCData* data = [SpCAppDelegate instance].data;
    data.latitude  = position.latitude;
    data.longitude = position.longitude;
#endif
}

- (NSString*)title
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string id = [self.id UTF8String];
    std::string search = db->query<std::string>("select query from search where id='" + id + "'");
    return [NSString stringWithFormat:@"title: %s", search.c_str()];
}

- (NSString*)subtitle
{
    return @"drag to relocate";
}
@end
