//
//  SpCData.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 30/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCData.h"
#import "SpCDatabase.h"
#import "SpCSearch.h"
#import <Foundation/Foundation.h>
#import <Foundation/NSJSONSerialization.h>
#include "Database.h"
 
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
    
    self.longitude = 0.0; //-dk:TODO use coordinate and deal with no coordinate set!
    self.latitude  = 0.0;
    return self;
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
    NSString* query = [NSString stringWithFormat:@"update_profile?x-id=%@&%@=%@", self.identity, name, encoded];
    [self sendHttpRequest: query];
}

- (void)updateSearches
{
    NSString* query = [NSString stringWithFormat:@"searches?x-id=%@", self.identity];
    [self sendHttpRequest: query];
}

- (void)addSearchWithText:(NSString*)text forSide:(NSString*)side
{
    // NSString* radius = @"&radius=5000";
    NSString* query = [NSString stringWithFormat:@"create_search?x-id=%@&side=%@&query=%@&longitude=-0.15&latitude=51.5", self.identity, side, [SpCData encodeURL:text]];
    [self sendHttpRequest: query];
}

- (void)addSearch:(SpCSearch*)search
{
    unsigned long i = 0, end = [self.searches count];
    for (; i != end; ++i) {
        if (search == [self.searches objectAtIndex: i]) {
            break;
        }
    }
    if (i == end) {
        [self.searches insertObject: search atIndex:0];
    }
    [self notify];
}


- (void)deleteSearch:(SpCSearch*)search
{
    for (unsigned long i = 0, end = [self.searches count]; i != end; ++i) {
        if (search == [self.searches objectAtIndex:i]) {
            [self.searches removeObjectAtIndex:i];
            break;
        }
    }
    NSString* query = [NSString stringWithFormat:@"delete_search?x-id=%@&search=%@",
                       self.identity, search.id];
    [self sendHttpRequest: query];
    [self notify];
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
            NSArray* array = NULL;
            if ([type isEqual:@"searches_response"]
                && (array = [dict objectForKey: @"searches"])) {
                NSLog(@"processing searches response: %ld", (long)[array count]);
                db->execute("delete from searches");
                for (long i = 0, count = [array count]; i != count; ++i) {
                    NSDictionary* dict = [array objectAtIndex: i];
                    NSNumber* id = [dict objectForKey: @"id"];
                    NSString* side = [dict objectForKey: @"side"];
                    NSString* query = [dict objectForKey: @"query"];
                    NSLog(@"search data: id='%@' side='%@' query='%@'", id, side, query);
                    if (id && side && query) {
                        NSString* sid = [NSString stringWithFormat:@"%@", id];
                        [self sendHttpRequest: [NSString stringWithFormat:@"search_results?x-id=%@&search=%@&request_id=%@", self.identity, id, id]];
                        std::string insert("insert into searches(id, side, search) values("
                                           "'" + db->escape([sid UTF8String]) + "', "
                                           "'" + db->escape([side UTF8String]) + "', "
                                           "'" + db->escape([query UTF8String]) + "');");
                        NSLog(@"insert query: '%s'", insert.c_str());
                        db->execute(insert);
                    }
                }
                [self notify];
            }
            else if ([type isEqual:@"search_results_response"]) {
                NSObject* sid = [dict objectForKey: @"request_id"];
                if (sid && (array = [dict objectForKey: @"results"])) {
                    std::string search(db->escape([[NSString stringWithFormat:@"%@", sid] UTF8String]));
                    db->execute("delete from results where search='" + search + "';");
                    for (long i = 0, count = [array count]; i != count; ++i) {
                        NSDictionary* dict = [array objectAtIndex: i];
                        NSObject* id = [dict objectForKey: @"id"];
                        NSObject* name = [dict objectForKey: @"real_name"];
                        NSObject* longitude = [dict objectForKey: @"longitude"];
                        NSObject* latitude = [dict objectForKey: @"latitude"];
                        NSObject* email = [dict objectForKey: @"email"];
                        std::string insert("insert into results(id, search, name, email, longitude, latitude) values("
                                           "'" + db->escape(id? [[NSString stringWithFormat:@"%@", id] UTF8String]: "") + "', "
                                           "'" + search + "', "
                                           "'" + db->escape(name? [[NSString stringWithFormat:@"%@", name] UTF8String]: "") + "', "
                                           "'" + db->escape(email? [[NSString stringWithFormat:@"%@", email] UTF8String]: "") + "', "
                                           "'" + db->escape(longitude? [[NSString stringWithFormat:@"%@", longitude] UTF8String]: "") + "', "
                                           "'" + db->escape(latitude? [[NSString stringWithFormat:@"%@", latitude] UTF8String]: "") + "'"
                                           ");");
                        NSLog(@"insert query: '%s'", insert.c_str());
                        db->execute(insert);
                    }
                    [self notify];
                }
                else {
                    NSLog(@"no request ID in results response!\n");
                }
            }
            else if ([type isEqual:@"create_search_response"]) {
                [self sendHttpRequest: [NSString stringWithFormat:@"searches?x-id=%@", self.identity]];
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
    NSLog(@"sending Http Request: '%@'", str);
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

- (int)numberOfSearchesFor:(NSString*)side
{
    unsigned long i = 0, end = [self.searches count];
    int count = 0;
    for (; i != end; ++i) {
        SpCSearch* search = [self.searches objectAtIndex: i];
        if ([side isEqualToString: search.side]) {
            ++count;
        }
    }
    return count;
}

@end
