//
//  SpCResultView.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 26/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCResultView.h"
#import "SpCDatabase.h"
#include "Database.h"
#include <sstream>

@interface SpCResultView()
@property NSString* key;
@end

@implementation SpCResultView

// ----------------------------------------------------------------------------

+ (SpCResultView*)makeWithKey:(NSString*)key
{
    return [[SpCResultView alloc] initWithKey:key];
}

+ (SpCResultView*)makeWithRow:(long)row
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::ostringstream condition;
    condition << "from match where rowid = " << row;
    std::string search = db->query<std::string>("select search " + condition.str());
    std::string other_search = db->query<std::string>("select other_search " + condition.str());
    return [SpCResultView makeWithKey: [NSString stringWithFormat:@"search = '%s' and other_search = '%s'", search.c_str(), other_search.c_str()]];
}

- (SpCResultView*)initWithKey:(NSString*)key
{
    self = [super init];
    self.key = key;
    return self;
}

// ----------------------------------------------------------------------------

- (CLLocationCoordinate2D)coordinate
{
    CLLocationCoordinate2D rc = {};

    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string key = [self.key UTF8String];
    rc.latitude  = db->query<double>("select latitude from match where " + key);
    rc.longitude = db->query<double>("select longitude from match where " + key);

    return rc;
}

- (NSString*)title
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string key = [self.key UTF8String];
    std::string value = db->query<std::string>("select username from match where " + key);
    return [NSString stringWithFormat:@"%s", value.c_str()];
}

- (NSString*)subtitle
{
    return self.fingerprint;
}

- (NSString*)fingerprint
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string key = [self.key UTF8String];
    std::string value = db->query<std::string>("select fingerprint from match where " + key);
    return [NSString stringWithFormat:@"%s", value.c_str()];
}

// ----------------------------------------------------------------------------

- (NSString*)identity
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string key = [self.key UTF8String];
    std::string value = db->query<std::string>("select username from match where " + key);
    if (value.empty()) {
        value = "<anonymous>";
    }
    return [NSString stringWithFormat:@"%s", value.c_str()];
}

// ----------------------------------------------------------------------------

- (NSString*)query
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string key = [self.key UTF8String];
    std::string value = db->query<std::string>("select query from match where " + key);
    if (value.empty()) {
        value = "<unknown>";
    }
    return [NSString stringWithFormat:@"%s", value.c_str()];
}

// ----------------------------------------------------------------------------

- (NSString*)email
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string key = [self.key UTF8String];
    std::string value = db->query<std::string>("select email from match where " + key);
    if (value.empty()) {
        value = "<unknown>";
    }
    return [NSString stringWithFormat:@"%s", value.c_str()];
}

// ----------------------------------------------------------------------------

- (long)rowid
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string key = [self.key UTF8String];
    return db->query<int>("select rowid from match where " + key, 0);
}

// ----------------------------------------------------------------------------
@end
