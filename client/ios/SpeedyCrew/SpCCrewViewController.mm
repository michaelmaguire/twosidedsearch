//
//  SpCCrewViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 28/09/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCCrewViewController.h"
#import "SpCDatabase.h"
#include "Database.h"
#include <sstream>

@implementation SpCCrewViewController

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    int rows = db->query<int>("select count(*) from crew");
    NSLog(@"there are %d crew chats", rows);
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:  @"Crew" forIndexPath:indexPath];
    std::ostringstream query;
    query << "select id from crew order by id limit 1 offset " << (long)indexPath.row;
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string name = db->query<std::string>(query.str());

    //-dk:TODO the label should probably be the name, a list of participants,
    //         and only then something generic; the crew name should probably 
    //         be created to start off as the search name and possibly be
    //         editable
    UILabel* label = (UILabel*)[cell.contentView viewWithTag:1];
    label.text = [NSString stringWithFormat:@"%s", name.c_str()];

    return cell;
}

@end
