//
//  SpCMessageViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 28/09/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCMessageViewController.h"
#import "SpCDatabase.h"
#import "SpCData.h"
#import "SpCAppDelegate.h"
#include "Database.h"
#include <sstream>

@interface SpCMessageViewController ()
@property bool registered;
@end
@implementation SpCMessageViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super init];
    if (self) {
        self.registered = NO;
    }
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (!self.registered) {
        SpCData* data = [SpCAppDelegate instance].data;
        __weak typeof(self) weakSelf = self;
        [data addListener:^(NSString* name, NSObject* object) {
                [weakSelf reloadMessages];
            } withId:@"MessageView"];
        self.registered = YES;
    }
    return 1;
}

-(void)reloadMessages
{
    [self.tableView reloadData];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    int rows = db->query<int>("select count(*) from message where crew = '"
                              + std::string([self.crewId UTF8String]) + "'");
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    std::ostringstream query;
    query << "select sender from message order by created limit 1 offset " << (long)indexPath.row;
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string sender = db->query<std::string>(query.str());
    std::string uuid = [[SpCAppDelegate instance].data.identity UTF8String];
    UITableViewCell *cell = [tableView
                                dequeueReusableCellWithIdentifier: (sender == uuid? @"Own Message": @"Other Message")
                                forIndexPath:indexPath];

    query.str("");
    query << "select body from message where crew = '"
          << [self.crewId UTF8String] << "' "
          << "order by created limit 1 offset " << (long)indexPath.row;
    std::string body = db->query<std::string>(query.str());
    UILabel* label = (UILabel*)[cell.contentView viewWithTag:1];
    label.text = [NSString stringWithFormat:@"%s", body.c_str()];

    return cell;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ([text isEqualToString:@"\n"]) {
        NSLog(@"adding message: %@", textView.text);
        NSString* body = [NSString stringWithFormat:@"crew=%@&id=%@&body=%@",
                                   self.crewId,
                                   [SpCData makeUUID],
                                   textView.text];
        [[SpCAppDelegate instance].data sendHttpRequest:@"send_message" withBody:(NSString*)body];
        [textView resignFirstResponder];
        return NO;
    }
    else {
        return YES;
    }
} 

@end
