//
//  SpCCrewSearchViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCCrewSearchViewController.h"

@interface SpCCrewSearchViewController ()

@end

@implementation SpCCrewSearchViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    NSLog(@"SpCCrewSearchViewController initWithStyle");
    self = [super initWithStyle:style];
    if (self) {
        NSLog(@"SpCCrewSearchViewController::initWithStyle");
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.side = @"SEEK";
    NSLog(@"SpCCrewSearchViewControl::viewDidLoad");
    //-dk:TODO remmove self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
 

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

/*
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    NSLog(@"SpCCrewSearchViewControl::didReceiveMemoryWarning");

}
 */

/*
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSLog(@"SpCCrewSearchViewControl::numberOfSecitonsInTable");
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"SpCCrewSearchViewControl::numberOfRowsInSection: %d", section);
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SearchBar" forIndexPath:indexPath];
    return cell;
}
 */

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

/*
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    NSLog(@"search text changed: '%@'", searchText);
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSLog(@"search was triggered: '%@'", searchBar.text);

    //if (0 < searchBar.text.length) {
    //    [self.search updateQueryWith: searchBar.text];
    //}
    [searchBar resignFirstResponder];
    
}
 */


@end
