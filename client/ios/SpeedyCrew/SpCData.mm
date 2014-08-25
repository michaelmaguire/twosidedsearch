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
#import <CommonCrypto/CommonDigest.h>
#include "Database.h"
#include <algorithm>
#include <iterator>
#include <iomanip>
#include <sstream>
#include <string>
 
@interface SpCData()
@property NSString*            baseURL;
@property NSMutableDictionary* listeners;
@property NSCache*             cache;
@end

@implementation SpCData

- (SpCData*)init
{
    SpCDatabase* database = [SpCDatabase database];
    self.baseURL = @"http://captain:cook@dev.speedycrew.com/api/1/";
    self.identity = [database querySetting: @"scid"];
    self.searches = [[NSMutableArray alloc] init]; //-dk:TODO recover stored searches
    self.listeners = [[NSMutableDictionary alloc] init];
    self.cache = [[NSCache alloc] init];
    self.longitude = 0.0; //-dk:TODO use coordinate and deal with no coordinate set!
    self.latitude  = 0.0;
    
    return self;
}

- (void)synchronise
{
    [self sendHttpRequest:@"synchronise" withBody:@""];
}

- (void)sendToken:(NSString*)token
{
    [self sendHttpRequest:@"set_notification" withBody:[NSString stringWithFormat:@"apple_device_token=%@", token]];
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
    NSString* query = [NSString stringWithFormat:@"%@=%@", name, encoded];
    [self sendHttpRequest:@"update_profile" withBody:query];
}

- (void)addSearchWithText:(NSString*)text forSide:(NSString*)side
{
    //-dk:TODO get the radius from the configuration
    // NSString* query = [NSString stringWithFormat:@"side=%@%@&query=%@&longitude=-0.15&latitude=51.5",
    self.longitude=-0.14;
    self.latitude=51.4;
    NSString* uuid  = [[[NSUUID UUID] UUIDString] lowercaseString];
    NSString* query = [NSString stringWithFormat:@"id=%@;side=%@%@;query=%@;longitude=%f;latitude=%f",
                        uuid,
                        side,
                        [side isEqual:@"SEEK"]? @";radius=5000": @"",
                        [SpCData encodeURL:text],
                        self.longitude,
                        self.latitude
                       ];
    [self sendHttpRequest:@"create_search" withBody: query];
}

- (void)deleteSearch:(NSString*)id
{
    NSLog(@"removing search: '%@'", id);
    NSString* query = [NSString stringWithFormat:@"search=%@", id];
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
        NSArray* queries = [dict objectForKey: @"sql"];
        if (queries) {
            try {
                SpeedyCrew::Database::Transaction transaction(db);
                for (int i = 0, count = [queries count]; i != count; ++i) {
                    db->execute([[queries objectAtIndex: i] UTF8String]);
                    // try { db->execute([[queries objectAtIndex: i] UTF8String]); } catch(...) {}
                }
                transaction.commit();
                [self notify];
                [[UIApplication sharedApplication] setApplicationIconBadgeNumber: 0];
            }
            catch (std::exception const& ex) {
                NSLog(@"ERROR: caught an exception while while executing SQL statements: %s", ex.what());
            }
        }
        NSArray* meta = [dict objectForKey: @"metadata"];
        if (meta) {
            for (int i = 0, count = [meta count]; i != count; ++i) {
                NSString* data = [[meta objectAtIndex:i] objectForKey: @"DELETE"];
                if (data) {
                    std::string str([data UTF8String]);
                    if (str.find("search/") == 0) {
                        NSLog(@"received a search delete: %s", str.substr(7).c_str());
                        db->execute("delete from expanded where id='" + str.substr(7) + "'");
                    }
                }
            }
        }

        if (type) {
            if ([type isEqual:@"synchronise_response"]
                || [type isEqual:@"create_search_response"]
                || [type isEqual:@"update_profile_response"]
                || [type isEqual:@"set_notification_response"]) {
            }
            else if ([type isEqual:@"delete_search_response"]) {
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

- (void)sendHttpRequest:(NSString*)query withBody:(NSString*)body
{
    NSString* str = [NSString stringWithFormat:@"%@%@", self.baseURL, query];

    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::ostringstream sout;
    sout << "x-id=" << db->query<std::string>("select value from settings where name='scid'");
    if (([query isEqual:@"synchronise"]
         || [query isEqual:@"create_search"]
         || [query isEqual:@"update_profile"]
         )
        && db->query<int>("select count(*) from control", 0) == 1) {
        sout << ";timeline=" << db->query<std::string>("select timeline from control");
        sout << ";sequence=" << db->query<std::string>("select sequence from control");
    } 
    sout << ([body isEqual:@""]? "": ";");
    body = [NSString stringWithFormat:@"%s%@", sout.str().c_str(), body];

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

- (void)loadImageFor:(UIImageView*)imageView from:(NSString*)urlstr withPlaceholder:(NSString*)name
{
    NSLog(@"loading image: url='%@'", urlstr);
    UIImage* image = [self.cache objectForKey: urlstr];
    if (image) {
        NSLog(@"setting image data from cache");
        imageView.image = image;
    }
    else {
        NSURL* url = [NSURL URLWithString:urlstr];
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
        NSOperationQueue* queue = [NSOperationQueue mainQueue];
        [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:
                             ^(NSURLResponse* resp, NSData* data, NSError* err) {
                if (data) {
                    NSLog(@"setting image data from url=%@", urlstr);
                    UIImage* image = [UIImage imageWithData:data];
                    [self.cache setObject: image forKey: urlstr];
                    imageView.image = image;
                }
                else {
                    NSLog(@"received error: %@", [err localizedDescription]);
                }
            }];
    }
}

+ (NSString*)gravatarURLForEmail:(NSString*)address
{
    std::string mail([address UTF8String]);
    mail.erase(std::remove(mail.begin(), mail.end(), ' '), mail.end());
    if (mail == "<unknown>") {
        return Nil;
    }
    std::transform(mail.begin(), mail.end(), mail.begin(),
                   [](unsigned char c){ return char(std::tolower(c)); });

    unsigned char buffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(mail.c_str(), mail.size(), buffer);
    std::ostringstream out;
    (out << std::hex).fill('0');
    for (unsigned char* it(std::begin(buffer)),* end(std::end(buffer));
         it != end; ++it) {
        out << std::setw(2) << static_cast<unsigned short>(*it);
    }
    return [NSString stringWithFormat:@"http://gravatar.com/avatar/%s", out.str().c_str()];
}

@end
