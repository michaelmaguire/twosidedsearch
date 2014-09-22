//
//  SpCMatchTableViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 24/08/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCMatchTableViewController.h"

@interface SpCMatchTableViewController ()

@end

@implementation SpCMatchTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return ([self.profile.real_name length] == 0? 0: 1)
        +  ([self.profile.username length] == 0? 0: 1)
        +  ([self.profile.email length] == 0? 0: 1)
        +  ([self.profile.message length] == 0? 0: 1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: (indexPath.row == 0? @"MatchOverview": @"MatchChat") forIndexPath:indexPath];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:  @"MatchOverview" forIndexPath:indexPath];
    UILabel* label = (UILabel*)[cell.contentView viewWithTag:1];

    int count(0);
    if ([self.profile.real_name length] != 0 && count++ == indexPath.row) {
        label.text = [NSString stringWithFormat:@"Name: %@", self.profile.real_name];
    }
    else if ([self.profile.username length] != 0 && count++ == indexPath.row) {
        label.text = [NSString stringWithFormat:@"User: %@", self.profile.username];
    }
    else if ([self.profile.email length] != 0 && count++ == indexPath.row) {
        label.text = [NSString stringWithFormat:@"Mail: %@", self.profile.email];
    }
    else if ([self.profile.message length] != 0 && count++ == indexPath.row) {
        label.text = self.profile.message;
    }
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

// ----------------------------------------------------------------------------

- (IBAction)onToggleView:(id)sender
{
    NSLog(@"toggling match view");
}

// ----------------------------------------------------------------------------

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    NSLog(@"intercepted URL click: '%@'", URL);
    if ([URL.scheme isEqual:@"mailto"]) {
        NSString *subject = self.result.query;
        NSString *address = URL.resourceSpecifier;
        NSLog(@"address='%@' subject='%@'", address, subject);

        NSURL *url = [[NSURL alloc]
                         initWithString:[NSString stringWithFormat:@"mailto:?to=%@&subject=%@",
                                                  [address stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding],
                                                  [subject stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]]];
        [[UIApplication sharedApplication] openURL:url];
        return NO;
    }
    return YES;
}

@end
