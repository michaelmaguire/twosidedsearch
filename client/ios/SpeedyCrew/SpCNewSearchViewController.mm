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
        [data addEventListener:^(char const* message) {
                [weakSelf addSearch: message];
            } forEvent:@"search-insert"];
        [data addEventListener:^(char const* message) {
                std::string msg(message);
                std::string::size_type slash(msg.find('/'));
                [weakSelf addMatch: msg.substr(slash + 1).c_str() forSearch: msg.substr(0, slash).c_str()];
            } forEvent:@"match-insert"];
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
    [self.html loadHTMLString: html baseURL: url];
    self.html.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;
}

- (void)addSearch:(char const*)cid {
    std::string id(cid);
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];

    std::ostringstream out;
    std::string text(db->query<std::string>("select query from search where id='" + id + "'"));
    out << "searchAdd(\"{ "
        << "\\\"id\\\":\\\"" << id << "\\\", "
        << "\\\"search\\\":\\\"" << text << "\\\", "
        << "\\\"state\\\":\\\"" << (db->query<int>("select state from expanded where id='" + id + "'", 1)? "open": "closed") << "\\\" "
        << "}\");";
    NSString* searchString = [NSString stringWithUTF8String: out.str().c_str()];
    NSLog(@"adding search: '%@'", searchString);
    [self.html stringByEvaluatingJavaScriptFromString:searchString];
}

- (void)addMatch:(char const*)cmid forSearch:(char const*)csid {
    std::string mid(cmid);
    std::string sid(csid);
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    
    std::string key("from match where search='" + sid + "' and other_search='" + mid + "'");
    std::ostringstream out;
    out << "searchAddMatch(\"{"
        << "\\\"searchId\\\":\\\"" << sid << "\\\", "
        << "\\\"matchId\\\":\\\"" << mid << "\\\", "
        << "\\\"search\\\":\\\"" << db->query<std::string>("select query " + key) << "\\\""
        << "}\");";
    NSString* matchString = [NSString stringWithUTF8String: out.str().c_str()];
    NSLog(@"adding match: '%@'", matchString);
    [self.html stringByEvaluatingJavaScriptFromString:matchString];
}

- (void)initializeSearches
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string side("SEEK");
    std::vector<std::string> searches(db->queryColumn("select id from search where side='" + side + "'"));
    for (std::vector<std::string>::const_iterator it(searches.begin()), end(searches.end());
         it != end; ++it) {
        [self addSearch: it->c_str()];

        std::vector<std::string> matches(db->queryColumn("select other_search from match where search='" + *it + "';"));
        for (std::vector<std::string>::const_iterator mit(matches.begin()), mend(matches.end());
             mit != mend; ++mit) {
            [self addMatch: mit->c_str() forSearch: it->c_str()];
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

- (void)setExpand:(NSString*)id to:(BOOL) state {
    std::string str([id UTF8String]);
    if (!str.empty() && str[0] == '/') {
        str = str.substr(1);
    }
    if (!str.empty()) {
        NSLog(@"setting state of id='%s' to %s", str.c_str(), state? "expanded": "collapsed");
        SpeedyCrew::Database* db = [SpCDatabase getDatabase];
        db->execute("insert or replace into  expanded (id, state) values('" + str + "', " + (state? "1": "0") + ")");
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
        else if ([request.URL.host isEqual:@"expand"]) {
            [self setExpand:request.URL.path to:YES];
        }
        else if ([request.URL.host isEqual:@"collapse"]) {
            [self setExpand:request.URL.path to:NO];
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
