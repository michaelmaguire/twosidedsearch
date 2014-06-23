//
//  SpCData.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 30/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCData.h"
#import "SpCDatabase.h"
// #import "SpCSearch.h"
#import <Foundation/Foundation.h>
#import <Foundation/NSJSONSerialization.h>
#include "Database.h"
#include <sstream>
 
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
    self.searches = [[NSMutableArray alloc] init]; //-dk:TODO recover stored searches
    self.listeners = [[NSMutableDictionary alloc] init];
    self.longitude = 0.0; //-dk:TODO use coordinate and deal with no coordinate set!
    self.latitude  = 0.0;
    [self synchronise];
    
    return self;
}

- (void)synchronise
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::ostringstream sout;
    sout << "x-id=" << db->query<std::string>("select value from settings where name='scid'");
    if (db->query<int>("select count(*) from control") == 1) {
        sout << "&timeline=" << db->query<std::string>("select timeline from control");
        sout << "&sequence=" << db->query<std::string>("select sequence from control");
    } 

    NSString* query = [NSString stringWithFormat:@"%s", sout.str().c_str()];
    [self sendHttpRequest:@"synchronise" withBody:query];
}

+ (NSString*)encodeURL:(NSString*)str
{
    return (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                               (__bridge CFStringRef)str,
                                                               NULL,
                                                               (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                               CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));;
}

- (void)updateSetting:(NSString*)name with:(NSString*)value
{
    SpCDatabase* database = [SpCDatabase database];
    [database updateSetting:name with:value];
    NSString* encoded = [value stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    NSString* query = [NSString stringWithFormat:@"x-id=%@&%@=%@", self.identity, name, encoded];
    [self sendHttpRequest:@"update_profile" withBody:query];
}

- (void)addSearchWithText:(NSString*)text forSide:(NSString*)side
{
    //-dk:TODO get the radius from the configuration
    NSString* query = [NSString stringWithFormat:@"x-id=%@&side=%@%@&query=%@&longitude=-0.15&latitude=51.5",
                        self.identity,
                        side,
                        [side isEqual:@"SEEK"]? @"&radius=5000": @"",
                        [SpCData encodeURL:text]
                       ];
    [self sendHttpRequest:@"create_search" withBody: query];
}

- (void)deleteSearch:(NSString*)id
{
    NSLog(@"removing search: '%@'", id);
    NSString* query = [NSString stringWithFormat:@"x-id=%@&search=%@", self.identity, id];
    [self sendHttpRequest:@"delete_search" withBody: query];
}

- (void)receivedResponse:(NSData*)data
{
    NSLog(@"received reponse: '%@'", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);
    NSData* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([json isKindOfClass: [NSDictionary class]]) {
        NSDictionary* dict = (NSDictionary*)json;
        NSString* type = [dict objectForKey: @"message_type"];
        SpeedyCrew::Database* db = [SpCDatabase getDatabase];
        if (type) {
            if ([type isEqual:@"synchronise_response"]) {
                NSArray* queries = [dict objectForKey: @"sql"];
                if (queries) {
                    //-dk:TODO enclose by a transaction!
                    for (int i = 0, count = [queries count]; i != count; ++i) {
                        db->execute([[queries objectAtIndex: i] UTF8String]);
                    }
                    [self notify];
                }
                else {
                    NSLog(@"ERROR: synchronise_response without 'sql' member");
                }
            }
            else if ([type isEqual:@"create_search_response"]
                     || [type isEqual:@"update_profile_response"]) {
                [self synchronise];
            } 
            else {
                NSLog(@"unprocessed message type='%@'", type);
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
    NSString* str = [NSString stringWithFormat:@"%@%@", self.baseURL, query];
    NSLog(@"sending HTTP GET: url='%@'", str);
    NSURL* url = [NSURL URLWithString:str];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    NSOperationQueue* q = [NSOperationQueue mainQueue];
    [NSURLConnection sendAsynchronousRequest:request queue:q completionHandler:
     ^(NSURLResponse* resp, NSData* d, NSError* err) {
         if (d) {
             [self receivedResponse:d];
         }
         else {
             NSLog(@"received error: %@", [err localizedDescription]);
         }
     }];
}

- (void)sendHttpRequest:(NSString*)query withBody:(NSString*)body
{
    NSString* str = [NSString stringWithFormat:@"%@%@", self.baseURL, query];
    NSLog(@"sending HTTP POST: url='%@' body='%@'", str, body);
    NSURL* url = [NSURL URLWithString:str];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSOperationQueue* q = [NSOperationQueue mainQueue];
    [NSURLConnection sendAsynchronousRequest:request queue:q completionHandler:
     ^(NSURLResponse* resp, NSData* d, NSError* err) {
         if (d) {
             [self receivedResponse:d];
         }
         else {
             NSLog(@"received error: %@", [err localizedDescription]);
         }
     }];
}

@end
