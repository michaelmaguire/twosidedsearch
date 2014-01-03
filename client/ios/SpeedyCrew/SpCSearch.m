//
//  SpCSearch.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 01/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearch.h"
#import "SpCSearchListener.h"
#import "SpCResult.h"
#import "Foundation/Foundation.h"
#import "Foundation/NSJSONSerialization.h"

@interface SpCSearch()
@property NSString*            uid;
@property NSString*            queryString;
@property NSMutableDictionary* listeners;
@end

@implementation SpCSearch


static int nextId = 0;

- (SpCSearch*)init
{
    self = [super init];
    self.uid = [NSString stringWithFormat: @"%d", ++nextId];
    self.queryString = @"";
    self.results = [[NSMutableArray alloc] init];
    self.listeners = [[NSMutableDictionary alloc] init];
    return self;
}

- (NSString*)id
{
    return self.uid;
}

- (NSString*)query
{
    return self.queryString;
}
- (NSString*)name
{
    return self.query;
}

- (void)updateQueryWith:(NSString*)query
{
    self.queryString = query;
    [self makeHttpRequestForQuery:self.queryString];
}

- (void)receivedResponse:(NSData*)response
{
    NSArray* json = [NSJSONSerialization JSONObjectWithData:response options:0 error:nil];
    NSMutableArray* results = [[NSMutableArray alloc] init];
    for (int i = 0, size = [json count]; i != size; ++i) {
        NSDictionary* result = [json objectAtIndex:i];
        NSString* id = [result objectForKey: @"id"];
        NSString* value = [result objectForKey: @"value"];
        NSLog(@"received result: id='%@' value='%@'", id, value);
        [results addObject:[[SpCResult alloc] initWithId:id value:value]];
    }
    self.results = results;
    
    NSEnumerator *enumerator = [self.listeners objectEnumerator];
    SpCSearchListener* listener = nil;
    NSLog(@"calling listeners: %d", [self.listeners count]);
    while ((listener = [enumerator nextObject])) {
        if (listener != nil) {
            [listener resultsChanged: self];
        }
        else {
            NSLog(@"listener is nil");
        }
    }
}

- (void)makeHttpRequestForQuery:(NSString*)query
{
    NSString* str = [NSString stringWithFormat:@"http://www.dietmar-kuehl.de/%@.json", query];
    NSURL* url = [NSURL URLWithString:str];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    NSOperationQueue* q = [NSOperationQueue mainQueue];
    [NSURLConnection sendAsynchronousRequest:request queue:q completionHandler:
        ^(NSURLResponse* resp, NSData* d, NSError* err) {
            if (d) {
                NSLog(@"received data");
                [self receivedResponse:d];
            }
            else {
                NSLog(@"received error...?");
            }
        }];
    NSLog(@"next statge: results for query '%s'", self.query.UTF8String);
}

- (void)addListener:(NSObject*)listener withId:(NSString*)id
{
    [self.listeners setObject:listener forKey:id];
    NSLog(@"added listener '%@' (total listeners=%d)", id, [self.listeners count]);
}
- (void)removeListenerWithId:(NSString*)id
{
    [self.listeners removeObjectForKey:id];
}


@end
