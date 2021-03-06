//
//  SpCMessage2ViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 29/09/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCMessage2ViewController.h"
#import "SpCAppDelegate.h"
#import "SpCData.h"
#import "SpCDatabase.h"
#include "Database.h"
#include <string>
#include <sstream>
#include <algorithm>

@interface SpCMessage2ViewController ()
@property bool registered;
@end

@implementation SpCMessage2ViewController

- (void)viewDidLoad
{
    if (!self.registered) {
        NSLog(@"registering message view for updates");
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
    std::string crewId = [self.crewId UTF8String];
    std::string uuid = [[SpCAppDelegate instance].data.identity UTF8String];

    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::vector<std::string> id(db->queryColumn("select id from message where crew = '" + crewId + "' order by created"));
    std::vector<std::string> sender(db->queryColumn("select sender from message where crew = '" + crewId + "' order by created"));
    std::vector<std::string> created(db->queryColumn("select created from message where crew = '" + crewId + "' order by created"));
    std::vector<std::string> body(db->queryColumn("select body from message where crew = '" + crewId + "' order by created"));
    std::size_t size(std::min(sender.size(), std::min(created.size(), std::min(id.size(), body.size()))));

    std::ostringstream out;
    out << "<!DOCTYPE html>\n";
    out << "<html><head><title></title>";
    out << "<link rel='stylesheet' type='text/css' href='crew.bundle/messages.css'/>";
    out << "<script type='text/javascript'>"
        << "function msgInitialize() {"
        << "    var iframe = document.createElement(\"IFRAME\");\n"
        << "     iframe.setAttribute(\"src\", \"js-frame:myObjectiveCFunction\");\n"
        << "     document.documentElement.appendChild(iframe);\n"
        << "     iframe.parentNode.removeChild(iframe);\n"
        << "     iframe = null;\n"
        << "}\n"
        << "function message_text() {"
        << "    var field = document.getElementById('message');"
        << "    return field.value;"
        << "}"
        << "</script>\n";
    out << "<head><body onLoad=\"msgInitialize()\">\n";
    out << "<div class='input'>";
    out << "<form action='message://send' method='get'><input class='message' id='message' type='text'></input></form>";
    out << "</div>\n";
    for (std::size_t i = 0; i != size; ++i) {
        out << "<a href='dummy://click/" << i << "'>";
        out << "<div class='" << (sender[i] == uuid? "own": "other") << "-message'>";
        out << "<div class='id'>" << id[i] << "</div>";
        std::string::size_type pos(created[i].find('.'));
        out << "<div class='date'>" << created[i].substr(0, pos) << "</div>";
        out << "<div class='body'>" << body[i] << "</div>";
        out << "</div>\n";
        out << "</a>\n";
    }
    out << "</body></html>\n";
    NSString* html = [NSString stringWithUTF8String: out.str().c_str()];
    NSURL* url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]; 
    [self.html loadHTMLString: html baseURL: url];
    self.html.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.html.frame = CGRectMake(0, self.topLayoutGuide.length,
                                 self.view.frame.size.width,
                                 self.view.frame.size.height - self.topLayoutGuide.length - self.bottomLayoutGuide.length);
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSLog(@"click! scheme=%@ host=%@ path=%@", request.URL.scheme, request.URL.host, request.URL.path);
    if ([request.URL.scheme isEqual:@"message"]) {
        NSString* message = [webView stringByEvaluatingJavaScriptFromString:@"message_text();"];
        NSLog(@"message: %@", message);
        NSString* body = [NSString stringWithFormat:@"crew=%@&id=%@&body=%@",
                                   self.crewId,
                                   [SpCData makeUUID],
                                   message];
        [[SpCAppDelegate instance].data sendHttpRequest:@"send_message" withBody:(NSString*)body];
        return NO;
    }
    return YES;
}

@end
