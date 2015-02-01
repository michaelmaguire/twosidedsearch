//
//  SpCNewSearchViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 25/01/2015.
//  Copyright (c) 2015 Dietmar Kühl. All rights reserved.
//

#import "SpCNewSearchViewController.h"
#include <sstream>

@interface SpCNewSearchViewController ()

@end

@implementation SpCNewSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //-dk:TODO register for updates
    [self setContent];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setContent {
    std::ostringstream out;
#if 0
    out << "<!DOCTYPE html>\n";
    out << "<html><head><title>Search</title>";
    out << "<link rel='stylesheet' type='text/css' href='crew.bundle/search.css'/>";
    out << "<script type='text/javascript'>"
        << "function search_text() {"
        << "    var field = document.getElementById('search');"
        << "    return field.value;"
        << "}"
        << "</script>\n";
    out << "<head><body>\n";
    out << "<div class='input'>";
    out << "<form action='message://send' method='get'><input class='search' id='search' type='text'></input></form>";
    out << "</div>\n";
    out << "<div class='bottom'>";
    out << "<form action='message://send' method='get'><input class='search' id='search' type='text'></input></form>";
    out << "</div>\n";
    out << "</body></html>\n";
#else
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
        "                  </nobr>"
        "                </div>"
        "                <div id=\"selection\" class=\"selection\"></div>"
        "            </div>"
        "            <div id=\"searches\" class=\"searches\"> </div>"
        "        </div>"
        "    </body>"
        "</html>";
#endif

    NSString* html = [NSString stringWithUTF8String: out.str().c_str()];
    NSURL* url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]; 
    [self.html loadHTMLString: html baseURL: url];
    self.html.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;
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
