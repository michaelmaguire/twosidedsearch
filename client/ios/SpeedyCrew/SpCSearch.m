//
//  SpCSearch.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 01/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearch.h"

@interface SpCSearch()
@property NSString* uid;
@property NSString* query;
@end

@implementation SpCSearch


static int nextId = 0;

- (SpCSearch*)init
{
    self = [super init];
    self.uid = [NSString stringWithFormat: @"%d", ++nextId];
    self.query = @"";
    return self;
}

- (NSString*)id
{
    return self.uid;
}

- (NSString*)name
{
    return self.query;
}

- (void)updateQueryWith:(NSString*)query
{
    self.query = query;
    NSLog(@"update results: %s", self.query.UTF8String);
}


@end
