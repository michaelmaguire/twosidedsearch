//
//  SpCData.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 30/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCData.h"
#import "SpcDatabase.h"
#import <Foundation/Foundation.h>
#import <Foundation/NSJSONSerialization.h>


@interface SpCData()
@property NSString* baseURL;
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

- (void)receivedResponse:(NSData*)data
{
    NSLog(@"received reponse: '%@'", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);
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
             NSLog(@"received data");
             [self receivedResponse:d];
         }
         else {
             NSLog(@"received error...?");
         }
     }];
    NSLog(@"next stage: results for query '%@'", query);
}

@end
