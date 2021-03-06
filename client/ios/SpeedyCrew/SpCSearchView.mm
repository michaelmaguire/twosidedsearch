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
    self.results  = [[NSMutableArray alloc] init];
    return self;
}

- (int)updateResults
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    //-dk:TODO splice the current and the new objects together to retain
    //   state and possibly position
    [self.results removeAllObjects];
    std::vector<std::string> names = db->queryColumn("select "
                                                     "search || ':' || other_search "
                                                     "from match where search='" + db->escape([self.id UTF8String]) + "';");
    for (std::vector<std::string>::const_iterator it(names.begin()), end(names.end()); it != end; ++it) {
        std::string::size_type colon(it->find(':'));
        [self.results addObject: [SpCResultView makeWithKey:[NSString stringWithFormat:@"search='%s' and other_search='%s'",
                                                                      it->substr(0, colon).c_str(),
                                                                      it->substr(colon + 1).c_str()]]];
    }
    return int([self.results count]);
}

// ----------------------------------------------------------------------------

- (CLLocationCoordinate2D)getPosition
{
    CLLocationCoordinate2D rc = {};
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string id = [self.id UTF8String];
    rc.latitude  = db->query<double>("select latitude from search where id='" + id + "';");
    rc.longitude = db->query<double>("select longitude from search where id='" + id + "';");
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
    SpCData* data = [SpCAppDelegate instance].data;
    data.latitude  = position.latitude;
    data.longitude = position.longitude;
}

- (NSString*)title
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string id = [self.id UTF8String];
    std::string search = db->query<std::string>("select query from search where id='" + id + "';");
    return [NSString stringWithUTF8String: search.c_str()];
}

- (NSString*)subtitle
{
    return @"drag to relocate";
}

// ----------------------------------------------------------------------------

- (bool)expanded
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    return db->query<int>(std::string("select state from expanded where id='") + [self.id UTF8String] + "';", 1);
}

- (void)setExpanded:(bool)value
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    db->execute(std::string("insert or replace into expanded (id, state) values(")
                            + "'" + [self.id UTF8String] + "', " + std::string(value? "1": "0") + ");");
}

@end
