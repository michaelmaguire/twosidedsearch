//
//  SpCCrewViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 28/09/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCCrewViewController.h"
#import "SpCAppDelegate.h"
#import "SpCMessage2ViewController.h"
#import "SpCDatabase.h"
#include "Database.h"
#include <sstream>

@interface SpCCrewViewController()
@property NSString* crewId;
@property bool      registered;
@end

@implementation SpCCrewViewController

- (void)viewDidLoad
{
    if (!self.registered) {
        NSLog(@"registering crew view for updates");
        self.registered = YES;
        SpCData* data = [SpCAppDelegate instance].data;
        __weak typeof(self) weakSelf = self;
        [data addListener:^(NSString* name, NSObject* object) {
                [weakSelf setContent];
            } withId:@"MessageView"];
    }
    [self setContent];
}

- (void)setContent
{
    std::string uuid = [[SpCAppDelegate instance].data.identity UTF8String];
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::vector<std::string> id(db->queryColumn("select id from crew order by id"));
    std::vector<std::string> name(db->queryColumn("select name from crew order by id"));
    std::size_t size(std::min(id.size(), name.size()));

    std::ostringstream out;
    out << "<html><head><title></title>";
    out << "<link rel='stylesheet' type='text/css' href='crew.bundle/crews.css'/>";
    out << "<head><body>\n";
    for (std::size_t i(0); i != size; ++i) {
        out << "<a href='crew://open/" << id[i] << "'>"
            << "<div class='crew'>"
            << "<div class='id'>" << id[i] << "</div>"
            << "<div class='name'>" << (name[i].empty()? "<no name>": name[i]) << "</div>";
        std::vector<std::string> member(db->queryColumn("select fingerprint from crew_member where crew = '" + id[i] + "'"));
        for (std::size_t m(0); m != member.size(); ++m) {
            out << "<div class='" << (member[m] == uuid? "self": "member") << "'>"
                << "<div class='mem-id'>" << member[m] << "</div>";
            for (std::string const& v:{ "username", "real_name", "email", "message" }) {
                std::string value(db->query<std::string>("select " + v + " from profile where fingerprint = '" + member[m] + "'"));
                if (!value.empty()) {
                    if (v == "email") {
                        out << "<div class='" << v << "'><a href='mailto://" << value << "'>" << value << "</a></div>";
                    }
                    else {
                        out << "<div class='" << v << "'>" << value << "</div>";
                    }
                }
            } 
            out << "</div>";
        }
        out << "</div>"
            << "</a>\n";
    }
    out << "</body></head>\n";

    NSString* html = [NSString stringWithFormat:@"%s", out.str().c_str()];
    NSURL* url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]; 
    [self.html loadHTMLString: html baseURL: url];
}

// ----------------------------------------------------------------------------

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSLog(@"click! scheme=%@ host=%@ path=%@", request.URL.scheme, request.URL.host, request.URL.path);
    if ([request.URL.scheme isEqual:@"crew"]) {
        self.crewId = [request.URL.path substringFromIndex:1];
        [self performSegueWithIdentifier:@"MessageSegue" sender:self];
        return NO;
    }
    return YES;
}

// ----------------------------------------------------------------------------

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"prepare for segue: %@", self.crewId);
    SpCMessage2ViewController* messages = [segue destinationViewController];
    messages.crewId = self.crewId;
}

@end
