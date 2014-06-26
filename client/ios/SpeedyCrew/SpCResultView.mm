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

@interface SpCResultView()
@property NSString* key;
@end

@implementation SpCResultView

#if 0
@property (nonatomic, readonly)       CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly, copy) NSString*              title;
@property (nonatomic, readonly, copy) NSString*              subtitle;
@property (readonly)                  NSString*              key;

#endif

// ----------------------------------------------------------------------------

+ (SpCResultView*)makeWithKey:(NSString*)key
{
    return [[SpCResultView alloc] initWithKey:key];
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
@end
