//
//  SpCData.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 30/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCData.h"
#import "SpcDatabase.h"
#import "SpCSearch.h"
#import "SpCSearchListener.h"
#import <Foundation/Foundation.h>
#import <Foundation/NSJSONSerialization.h>


@interface SpCData()
@property NSString* baseURL;
@property NSMutableDictionary* listeners;
@end

@implementation SpCData

- (SpCData*)init
{
    SpCDatabase* database = [SpCDatabase database];
    self.baseURL = @"http://captain:cook@dev.speedycrew.com/api/1/";
    self.identity = [database querySetting: @"scid"];
    NSString* query = [NSString stringWithFormat:@"profile?x-id=%@", self.identity];
    [self sendHttpRequest: query];
    
    self.searches = [[NSMutableArray alloc] init]; //-dk:TODO recover stored searches
    self.listeners = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)updateSetting:(NSString*)name with:(NSString*)value
{
    SpCDatabase* database = [SpCDatabase database];
    [database updateSetting:name with:value];
    NSString* encoded = [value stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    NSString* query = [NSString stringWithFormat:@"update_profile?x-id=%@&%@=%@", self.identity, name, encoded];
    [self sendHttpRequest: query];
}

- (void)updateSearches
{
    NSString* query = [NSString stringWithFormat:@"searches?x-id=%@", self.identity];
    [self sendHttpRequest: query];
}


- (void)receivedResponse:(NSData*)data
{
    NSLog(@"received reponse: '%@'", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);
    NSData* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([json isKindOfClass: [NSDictionary class]]) {
        NSDictionary* dict = (NSDictionary*)json;
        NSString* type = [dict objectForKey: @"message_type"];
        if (type) {
            NSArray* array = NULL;
            if ([type isEqual:@"searches_response"]
                && (array = [dict objectForKey: @"searches"])) {
                NSLog(@"processing searches response: %d", [array count]);
                [self.searches removeAllObjects];
                for (int i = 0, count = [array count]; i != count; ++i) {
                    SpCSearch* search = [[SpCSearch alloc] initWithDictionary: [array objectAtIndex: i]];
                    [self.searches addObject: search];
                }
                [self notify];
            }
            else {
                NSLog(@"unprocessed message type=: %@", type);
            }
        }
        else {
            NSLog(@"no message type found: %@", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);
        }
    }
    else {
        NSLog(@"received unknown reponse: '%@'", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);
    }
}

- (void)sendHttpRequest:(NSString*)query
{
    NSLog(@"sending Http Request: '%@'", query);
    NSString* str = [NSString stringWithFormat:@"%@%@", self.baseURL, query];
    NSURL* url = [NSURL URLWithString:str];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    NSOperationQueue* q = [NSOperationQueue mainQueue];
    [NSURLConnection sendAsynchronousRequest:request queue:q completionHandler:
     ^(NSURLResponse* resp, NSData* d, NSError* err) {
         if (d) {
             [self receivedResponse:d];
         }
         else {
             NSLog(@"received error...?");
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
- (void)notify
{
    NSEnumerator *enumerator = [self.listeners objectEnumerator];
    SpCSearchListener* listener = nil;
    while ((listener = [enumerator nextObject])) {
        if (listener != nil) {
            NSLog(@"sending resultsChanged");
            [listener resultsChanged: self];
        }
        else {
            NSLog(@"listener is nil");
        }
    }
}


@end
