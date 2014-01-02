//
//  SpCViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCViewController.h"
#import "SpCAppDelegate.h"
#import "SpCResult.h"

@interface SpCViewController ()

@end

@implementation SpCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.actions = [[NSMutableArray alloc] initWithObjects:@"Availability", @"Invites", @"Events", @"Messages", nil];
    SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    self.searches = delegate.data.searches;
    self.currentSearch = [[SpCSearch alloc] init];
    [self.currentSearch addListener:self withId: @"ViewController"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (0 == indexPath.section)
    {
        if (0 == indexPath.row) {
            return [tv dequeueReusableCellWithIdentifier:@"TextCell"];
        }
        UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"ResultCell"];
        SpCResult* result = [self.currentSearch.results objectAtIndex:indexPath.row - 1];
        cell.textLabel.text = [NSString stringWithFormat:@"id=%@ value=%@", result.id, result.value];
        return cell;
    }
    else if (1 == indexPath.section)
    {
        UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"ResultCell"];
        SpCSearch* search = [self.searches objectAtIndex:indexPath.row];
        cell.textLabel.text = search.name;
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
    int result = section == 0
        ? 1 + [self.currentSearch.results count]
        : section == 1? [self.searches count]: [self.actions count];
    return result;
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (0 < textField.text.length) {
        [self.currentSearch updateQueryWith: textField.text];
        return NO;
    }
    return YES;
}

- (IBAction)updateSearch:(id)sender
{
    if (0 < self.currentSearch.name.length) {
        NSLog(@"adding query %s", self.currentSearch.name.UTF8String);
        int index = 0, size = [self.searches count];
        for (; index != size; ++index) {
            SpCSearch* search = self.searches[index];
            if ([search.id isEqualToString: self.currentSearch.id]) {
                break;
            }
        }
        if (index != size ) {
            NSLog(@"update name=%s", self.currentSearch.name.UTF8String);
        }
        else {
            NSLog(@"adding name=%s", self.currentSearch.name.UTF8String);
            [self.searches insertObject: self.currentSearch atIndex: 0];
            index = 1;
        }
        NSIndexSet* indices = [[NSIndexSet alloc] initWithIndex:index];
        [self.tableView reloadSections:indices withRowAnimation: UITableViewRowAnimationNone];
    }
}

- (void)resultsChanged:(id)sender
{
    NSLog(@"control control: received change!");
    NSIndexSet* indices = [[NSIndexSet alloc] initWithIndex:0];
    [self.tableView reloadSections:indices withRowAnimation: UITableViewRowAnimationNone];

}
@end
