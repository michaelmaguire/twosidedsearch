//
//  SpCInvitesController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 05/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCInvitesController.h"

@interface SpCInvitesController ()

@end

@implementation SpCInvitesController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.invites = [[NSMutableArray alloc] initWithObjects:@"Invite A", @"Invite B", @"Invite C", @"Invite D", @"Invite E", nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cell"];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    
    cell.textLabel.text = [self.invites objectAtIndexedSubscript:indexPath.row];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section
{
    return [self.invites count];
}

@end
