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
@property NSString* id;
@end

@implementation SpCResultView

#if 0
@property (nonatomic, readonly)       CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly, copy) NSString*              title;
@property (nonatomic, readonly, copy) NSString*              subtitle;
@property (readonly)                  NSString*              id;

#endif

// ----------------------------------------------------------------------------

+ (SpCResultView*)makeWithId:(NSString*)id
{
    return [[SpCResultView alloc] initWithId:id];
}

- (SpCResultView*)initWithId:(NSString*)id
{
    self = [super init];
    self.id = id;
    return self;
}

// ----------------------------------------------------------------------------

- (CLLocationCoordinate2D)coordinate
{
    CLLocationCoordinate2D rc = {};

    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string id = [self.id UTF8String];
    rc.latitude  = db->query<double>("select latitude from results where id='" + id + "'");
    rc.longitude = db->query<double>("select longitude from results where id='" + id + "'");

    return rc;
}

- (NSString*)title
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string id = [self.id UTF8String];
    std::string value = db->query<std::string>("select name from results where id='" + id + "'");
    return [NSString stringWithFormat:@"%s", value.c_str()];
}

- (NSString*)subtitle
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string id = [self.id UTF8String];
    std::string value = db->query<std::string>("select email from results where id='" + id + "'");
    return [NSString stringWithFormat:@"%s", value.c_str()];
}

// ----------------------------------------------------------------------------
@end
