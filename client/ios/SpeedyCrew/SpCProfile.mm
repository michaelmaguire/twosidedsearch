//
//  SpCProfile.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 25/08/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCProfile.h"
#import "SpCDatabase.h"
#import "database.h"

@interface SpCProfile()
@property NSString* fingerprint;
@end

@implementation SpCProfile

// ----------------------------------------------------------------------------

+ (SpCProfile*)makeWithFingerprint:(NSString*)fingerprint
{
    return [[SpCProfile alloc] initWithFingerprint: fingerprint];
}

- (SpCProfile*)initWithFingerprint:(NSString*)fingerprint
{
    self = [super init];
    self.fingerprint = fingerprint;
    return self;
}

// ----------------------------------------------------------------------------

- (NSString*)real_name
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string fingerprint = [self.fingerprint UTF8String];
    std::string value = db->query<std::string>("select real_name from profile where fingerprint='" + fingerprint + "'");
    return [NSString stringWithUTF8String: value.c_str()];
}

- (NSString*)username
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string fingerprint = [self.fingerprint UTF8String];
    std::string value = db->query<std::string>("select username from profile where fingerprint='" + fingerprint + "'");
    return [NSString stringWithUTF8String: value.c_str()];
}

- (NSString*)email
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string fingerprint = [self.fingerprint UTF8String];
    std::string value = db->query<std::string>("select email from profile where fingerprint='" + fingerprint + "'");
    return [NSString stringWithUTF8String: value.c_str()];
}

- (NSString*)message
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string fingerprint = [self.fingerprint UTF8String];
    std::string value = db->query<std::string>("select message from profile where fingerprint='" + fingerprint + "'");
    return [NSString stringWithUTF8String: value.c_str()];
}

// ----------------------------------------------------------------------------

@end
