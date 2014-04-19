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

- (SpCResult*)initWithDictionary: (NSDictionary*) dict
{
    self = [super init];
    self.id = [dict objectForKey: @"id"];
    self.value = @"";
    NSString* tmp;
    NSNumber* dist;
    if ((dist = [dict objectForKey: @"distance"])) {
        self.value = [NSString stringWithFormat: @"%@distance=%@ ", self.value, [dist stringValue]];
    }
    if ((tmp = [dict objectForKey: @"real_name"]) && [tmp isKindOfClass: [NSString class]]) {
        self.value = [NSString stringWithFormat: @"%@name=%@ ", self.value, tmp];
    }
    if ((tmp = [dict objectForKey: @"username"]) && [tmp isKindOfClass: [NSString class]]) {
        self.value = [NSString stringWithFormat: @"%@username=%@ ", self.value, tmp];
    }
    if ((tmp = [dict objectForKey: @"email"]) && [tmp isKindOfClass: [NSString class]]) {
        self.value = [NSString stringWithFormat: @"%@email=%@ ", self.value, tmp];
    }
    if ((tmp = [dict objectForKey: @"city"]) && [tmp isKindOfClass: [NSString class]]) {
        self.value = [NSString stringWithFormat: @"%@city=%@ ", self.value, tmp];
    }
    if ((tmp = [dict objectForKey: @"postcode"]) && [tmp isKindOfClass: [NSString class]]) {
        self.value = [NSString stringWithFormat: @"%@postcode=%@ ", self.value, tmp];
    }
    if ((tmp = [dict objectForKey: @"address"]) && [tmp isKindOfClass: [NSString class]]) {
        self.value = [NSString stringWithFormat: @"%@address=%@ ", self.value, tmp];
    }
    if ((tmp = [dict objectForKey: @"country"]) && [tmp isKindOfClass: [NSString class]]) {
        self.value = [NSString stringWithFormat: @"%@country=%@ ", self.value, tmp];
    }
    NSLog(@"got result: %@", self.value);
    return self;
}

@end
