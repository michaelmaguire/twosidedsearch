//
//  SpCViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCViewController.h"
#import "SpCAppDelegate.h"

@interface SpCViewController ()

@end

@implementation SpCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.actions = [[NSMutableArray alloc] initWithObjects:@"Availability", @"Invites", @"Events", @"Messages", nil];
    SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    self.searches = delegate.data.searches;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"add controller cell row=%ld", (long)indexPath.row);
    if (0 == indexPath.section)
    {
        return [tv dequeueReusableCellWithIdentifier:@"TextCell"];
    }
    else if (1 == indexPath.section)
    {
        UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"ResultCell"];
        cell.textLabel.text = [self.searches objectAtIndexedSubscript:indexPath.row];
        return cell;
    }else
    {
        UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"ActionCell"];
        cell.textLabel.text = [self.actions objectAtIndexedSubscript:indexPath.row];
        return cell;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"number-of-rows-in-section=%ld", (long)section);
    return section == 0? 1: section == 1? [self.searches count]: [self.actions count];
}

- (NSString*)tableView:(UITableView*)tv titleForHeaderInSection:(NSInteger)section
{
    return section == 0? nil: section == 1? @"Searches": @"Actions";
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UINavigationController *navController = (UINavigationController*)delegate.window.rootViewController;

    if (indexPath.row == 1) {
        UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"Invites"];
        [navController pushViewController:viewController animated:YES];
    }
}
@end
