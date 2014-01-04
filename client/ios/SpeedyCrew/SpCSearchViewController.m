//
//  SpCSearchViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearchViewController.h"
#import "SpCResult.h"

@interface SpCSearchViewController ()
@property UISearchBar* searchBar;
@end

@implementation SpCSearchViewController

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
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.search addListener:self withId:@"Search"];

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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0 == section? 1
         : 1 == section? [self.search.results count]
         : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)path
{
    if (0 == path.section) {
        UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"SearchField"];
        UIView* view = [cell.contentView viewWithTag:0];
        if (view && 1 == view.subviews.count) {
            self.searchBar = [view.subviews objectAtIndex:0];
            self.searchBar.text = self.search.query;
        }
        return cell;
    }
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"Result" forIndexPath:path];
    SpCResult* result = [self.search.results objectAtIndex:path.row];
    cell.textLabel.text = result.value;
    
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
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
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

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    //-dk:TODO act upon these events! NSLog(@"search text changed: '%@'", searchText);
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    if (0 < searchBar.text.length) {
        [self.search updateQueryWith: searchBar.text];
    }
}

- (void)resultsChanged:(SpCSearch*)search
{
    NSIndexSet* indices = [[NSIndexSet alloc] initWithIndex:1];
    [self.tableView reloadSections:indices withRowAnimation: UITableViewRowAnimationNone];

}

@end
