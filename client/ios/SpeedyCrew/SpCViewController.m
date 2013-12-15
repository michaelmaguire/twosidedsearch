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

    cell.textLabel.text = [self.actions objectAtIndexedSubscript:indexPath.row];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section
{
    return [self.actions count];
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
