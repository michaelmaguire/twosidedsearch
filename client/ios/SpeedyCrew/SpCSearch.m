//
//  SpCSearch.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 01/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearch.h"
#import "SpCResult.h"
#import "SpCAppDelegate.h"
#import "Foundation/Foundation.h"
#import "Foundation/NSJSONSerialization.h"

@interface SpCSearch()
@property NSString*            uid;
@property NSString*            uuid; // user identifier
@property NSString*            queryString;
@property NSString*            side;
@end

@implementation SpCSearch

static int       nextId = 0;
static NSString* baseURL = @"http://captain:cook@dev.speedycrew.com/api/1";

- (NSString*)encodeURL:(NSString*)str
{
    return (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                               (__bridge CFStringRef)str,
                                                               NULL,
                                                               (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                               CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));;
}


- (SpCSearch*)init
{
    self = [super init];
    self.uid = [NSString stringWithFormat: @"%d", ++nextId];
    SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    self.uuid = delegate.data.identity;
    self.queryString = @"";
    self.results = [[NSMutableArray alloc] init];
    self.side = @"PROVIDE";
    return self;
}

- (SpCSearch*)initWithSide:(NSString*)side
{
    self = [super init];
    self.uid = [NSString stringWithFormat: @"%d", ++nextId];
    SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    self.uuid = delegate.data.identity;
    self.queryString = @"";
    self.results = [[NSMutableArray alloc] init];
    self.side = side;
    return self;
}

- (SpCSearch*)initWithDictionary:(NSDictionary*)dict
{
    self = [self init];
    NSString* tmp = NULL;
    if ((tmp = [dict objectForKey: @"id"])) {
        self.uid  = tmp;
        [self makeHttpRequestForResults];
    }
    if ((tmp = [dict objectForKey: @"side"])) {
        self.side = tmp;
    }
    if ((tmp = [dict objectForKey: @"query"])) {
        self.queryString = tmp;
    }
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
    NSLog(@"updateQueryWith:%@", query);
    self.queryString = query;
    [self makeHttpRequestForQuery:self.queryString];
}

- (void)receivedResponse:(NSData*)response
{
    NSData* json = [NSJSONSerialization JSONObjectWithData:response options:0 error:nil];
    if ([json isKindOfClass: [NSArray class]]) {
        NSArray* jsonArray = (NSArray*)json;
        NSLog(@"JSON array count=%ld", (long)[jsonArray count]);
        NSMutableArray* results = [[NSMutableArray alloc] init];
        for (long i = 0, size = [jsonArray count]; i != size; ++i) {
            NSDictionary* result = [jsonArray objectAtIndex:i];
            NSString* id = [result objectForKey: @"id"];
            NSString* value = [result objectForKey: @"value"];
            [results addObject:[[SpCResult alloc] initWithId:id value:value]];
        }
        self.results = results;
    
        [self notify];
    }
    else if ([json isKindOfClass: [NSDictionary class]]) {
        NSDictionary* dict = (NSDictionary*)json;
        NSString* type = [dict objectForKey: @"message_type"];
        if (type) {
            NSString* id = nil;
            if ([type isEqual:@"create_search_response"]
                && (id = [dict objectForKey: @"search_id"])) {
                self.uid = id;
                [self makeHttpRequestForResults];
                [[SpCAppDelegate instance].data addSearch:self];
            }
            else {
                NSLog(@"unprocessed message type: %@", type);
            }
        }
        
    }
    else {
        NSLog(@"some other JSON object");
    }
}

- (void)makeHttpRequestForResults
{
    NSLog(@"making request for results: %@", self.uid);
    NSString* str =[NSString stringWithFormat: @"%@/search_results?x-id=%@&search=%@", baseURL, self.uuid, self.uid];
    NSLog(@"actual query='%@'", str);
    NSURL* url = [NSURL URLWithString:str];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    NSOperationQueue* q = [NSOperationQueue mainQueue];
    [NSURLConnection sendAsynchronousRequest:request queue:q completionHandler:
        ^(NSURLResponse* resp, NSData* d, NSError* err) {
            if (d) {
                NSString* s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                NSLog(@"received data: '%@'", s);
                NSData* json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                if ([json isKindOfClass: [NSDictionary class]]) {
                    NSDictionary* dict = (NSDictionary*)json;
                    NSArray* results = [dict objectForKey: @"results"];
                    if (results) {
                        [self.results removeAllObjects];
                        for (long i = 0, count = [results count]; i != count; ++i) {
                            [self.results addObject: [[SpCResult alloc] initWithDictionary: [results objectAtIndex: i]]];
                        }
                    }
                }
            }
            else {
                NSLog(@"received error: %@", [err localizedDescription]);
            }
        }];
}

- (void)makeHttpRequestForQuery:(NSString*)query
{
    NSLog(@"making request for query: %s", query.UTF8String);
    NSString* side = [query hasSuffix: @"seek"]? @"SEEK&radius=5000": @"PROVIDE";
    SpCData* data = [SpCAppDelegate instance].data;
    NSString* str =[NSString stringWithFormat: @"%@/create_search?x-id=%@&side=%@&longitude=%f&latitude=%f&request_id=%@&query=%@",
                    baseURL, self.uuid, side,
                    data.longitude, data.latitude,
                    self.uid, [self encodeURL:query]];
    NSLog(@"actual query='%@'", str);
    NSURL* url = [NSURL URLWithString:str];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    NSOperationQueue* q = [NSOperationQueue mainQueue];
    [NSURLConnection sendAsynchronousRequest:request queue:q completionHandler:
     ^(NSURLResponse* resp, NSData* d, NSError* err) {
         if (d) {
             NSString* s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
             NSLog(@"received data: '%@'", s);
             [self receivedResponse:d];
         }
         else {
             NSLog(@"received error: %@", [err localizedDescription]);
         }
     }];

}

@end
