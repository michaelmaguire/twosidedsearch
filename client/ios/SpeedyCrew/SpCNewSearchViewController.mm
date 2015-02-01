//
//  SpCNewSearchViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 25/01/2015.
//  Copyright (c) 2015 Dietmar Kühl. All rights reserved.
//

#import "SpCNewSearchViewController.h"
#import "SpCAppDelegate.h"
#import "SpCData.h"
#import "SpCDatabase.h"

#include "Database.h"
#include <sstream>

@interface SpCNewSearchViewController ()
@property bool registered;
@end

@implementation SpCNewSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    if (!self.registered) {
        NSLog(@"registering crew search view for updates");
        self.registered = YES;
        SpCData* data = [SpCAppDelegate instance].data;
        __weak typeof(self) weakSelf = self;
        [data addListener:^(NSString* name, NSObject* object) {
                [weakSelf receivedUpdate:name];
            } withId:@"CrewSearchView"];
    }

    [self setContent];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)receivedUpdate:(NSString*)name {
    NSLog(@"crew search received update with name='%@'", name);
}

- (void)setContent {
    std::ostringstream out;
    out << "<!DOCTYPE html PUBLIC \"-//IETF//DTD HTML//EN\">"
        "<html>"
        "    <head>"
        "        <title>search</title>"
        "        <meta charset=\"UTF-8\"/>"
        "        <link rel=\"stylesheet\" type=\"text/css\" href=\"crew.bundle/search.css\"/>"
        "        <script type=\"text/javascript\" src=\"crew.bundle/search.js\"></script>"
        "    </head>"
        "    <body onload=\"searchInitialize()\">"
        "        <div class=\"outer\">"
        "            <div class=\"head\">"
        "                <div class=\"input\">"
        "                  <nobr>"
        "                    <input class=\"search\" id=\"search\" type=\"text\"></input>"
        "                    <input class=\"none\" id=\"cancel\" type=\"button\" value=\"cancel\"></input>"
        "                    <input class=\"none\" id=\"send\" type=\"button\" value=\"send\"></input>"
        "                  </nobr>"
        "                </div>"
        "                <div id=\"selection\" class=\"selection\"></div>"
        "            </div>"
        "            <div id=\"searches\" class=\"searches\"> </div>"
        "        </div>"
        "    </body>"
        "</html>";

    NSString* html = [NSString stringWithUTF8String: out.str().c_str()];
    NSURL* url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]; 
    NSLog(@"set HTML: %@", html);
    [self.html loadHTMLString: html baseURL: url];
    self.html.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;
    NSLog(@"setting HTML done");
}

- (void)initializeSearches
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string side("SEEK");
    std::vector<std::string> searches(db->queryColumn("select id from search where side='" + side + "'"));
    NSLog(@"initial searches: %d", int(searches.size()));
    for (std::vector<std::string>::const_iterator it(searches.begin()), end(searches.end());
         it != end; ++it) {
        std::ostringstream out;
        std::string text(db->query<std::string>("select query from search where id='" + *it + "'"));
        out << "searchAdd(\"{ "
            << "\\\"id\\\":\\\"" << *it << "\\\", "
            << "\\\"search\\\":\\\"" << text << "\\\", "
            << "\\\"state\\\":\\\"open\\\" "
            << "}\");";
        NSString* searchString = [NSString stringWithUTF8String: out.str().c_str()];
        NSLog(@"adding search: '%@'", searchString);
        [self.html stringByEvaluatingJavaScriptFromString:searchString];

        std::vector<std::string> matches(db->queryColumn("select other_search from match where search='" + *it + "';"));
        for (std::vector<std::string>::const_iterator mit(matches.begin()), mend(matches.end());
             mit != mend; ++mit) {
            std::string key("from match where search='" + *it + "' and other_search='" + *mit + "'");
            std::ostringstream out;
            out << "searchAddMatch(\"{"
                << "\\\"searchId\\\":\\\"" << *it << "\\\", "
                << "\\\"search\\\":\\\"" << db->query<std::string>("select query " + key) << "\\\""
                << "}\");";
            NSString* matchString = [NSString stringWithUTF8String: out.str().c_str()];
            NSLog(@"adding match: '%@'", matchString);
            [self.html stringByEvaluatingJavaScriptFromString:matchString];
        }
    }
    NSLog(@"adding searches done");
}

- (void)sendSearch:(NSString*)search
{
    std::string str([search UTF8String]);
    if (!str.empty() && str[0] == '/') {
        str = str.substr(1);
    }
    if (!str.empty()) {
        NSLog(@"sending a new search: %s", str.c_str());
        SpCData* data = [SpCAppDelegate instance].data;
        [data addSearchWithText:[NSString stringWithUTF8String: str.c_str()] forSide:@"SEEK"];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.scheme isEqual:@"jscall"]) {
        NSLog(@"click! scheme=%@ host=%@ path=%@", request.URL.scheme, request.URL.host, request.URL.path);
        if ([request.URL.host isEqual:@"initialize"]) {
            [self initializeSearches];
        }
        else if ([request.URL.host isEqual:@"send"]) {
            [self sendSearch:request.URL.path];
        }
        else {
            NSLog(@"something wants to get back from JavaScript - but failed");
        }

        return NO;
    }
    return YES;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    NSLog(@"rotating: view=(%f, %f) html=(%f, %f)x(%f, %f)",
          self.view.bounds.size.width, self.view.bounds.size.height,
          self.html.bounds.origin.x, self.html.bounds.origin.y,
          self.html.bounds.size.width, self.html.bounds.size.height);
#if 0
    CGRect frame = self.html.frame;
    frame.size.width = self.view.frame.size.width;
    frame.origin.x = 0;
    self.html.frame = frame;
#endif
}


@end
