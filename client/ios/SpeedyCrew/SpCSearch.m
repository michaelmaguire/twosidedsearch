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
#import "SpCAppDelegate.h"
#import "Foundation/Foundation.h"
#import "Foundation/NSJSONSerialization.h"

@interface SpCSearch()
@property NSString*            uid;
@property NSString*            uuid; // user identifier
@property NSString*            queryString;
@property NSMutableDictionary* listeners;
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

- (SpCSearch*)init;
{
    self = [super init];
    self.uid = [NSString stringWithFormat: @"%d", ++nextId];
    SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    self.uuid = delegate.data.identity;
    self.queryString = @"";
    self.results = [[NSMutableArray alloc] init];
    self.listeners = [[NSMutableDictionary alloc] init];
    self.side = @"PROVIDE";
    return self;
}

- (SpCSearch*)initWithDictionary:(NSDictionary*)dict
{
    self = [self init];
    NSString* tmp = NULL;
    if ((tmp = [dict objectForKey: @"id"])) {
        self.uid  = tmp;
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
    self.queryString = query;
    [self makeHttpRequestForQuery:self.queryString];
}

- (void)receivedResponse:(NSData*)response
{
    NSData* json = [NSJSONSerialization JSONObjectWithData:response options:0 error:nil];
    if ([json isKindOfClass: [NSArray class]]) {
        NSArray* jsonArray = (NSArray*)json;
        NSLog(@"JSON array count=%d", [jsonArray count]);
        NSMutableArray* results = [[NSMutableArray alloc] init];
        for (int i = 0, size = [jsonArray count]; i != size; ++i) {
            NSDictionary* result = [jsonArray objectAtIndex:i];
            NSString* id = [result objectForKey: @"id"];
            NSString* value = [result objectForKey: @"value"];
            [results addObject:[[SpCResult alloc] initWithId:id value:value]];
        }
        self.results = results;
    
        NSEnumerator *enumerator = [self.listeners objectEnumerator];
        SpCSearchListener* listener = nil;
        while ((listener = [enumerator nextObject])) {
            if (listener != nil) {
                [listener resultsChanged: self];
            }
            else {
                NSLog(@"listener is nil");
            }
        }
    }
    else if ([json isKindOfClass: [NSDictionary class]]) {
        NSLog(@"JSON dictionary");
    }
    else {
        NSLog(@"some other JSON object");
    }
}

- (void)makeHttpRequestForQuery:(NSString*)query
{
    NSLog(@"making request for query: %s", query.UTF8String);
    NSString* str =[NSString stringWithFormat: @"%@/create_search?x-id=%@&side=PROVIDE&longitude=-0.15&latitude=51.5&request_id=%@&query=%@",
                    baseURL, self.uuid, self.uid, [self encodeURL:query]];
    NSLog(@"actual query='%@'", str);
    // str = [NSString stringWithFormat:@"http://www.dietmar-kuehl.de/%@.json", query];
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

- (void)addListener:(NSObject*)listener withId:(NSString*)id
{
    [self.listeners setObject:listener forKey:id];
}
- (void)removeListenerWithId:(NSString*)id
{
    [self.listeners removeObjectForKey:id];
}


@end
