//
//  SpCSearchViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearchViewController.h"
#import "SpCResult.h"
#import "SpCAppDelegate.h"

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
    __weak typeof(self) weakSelf = self;
    [self.search addListener:^(NSString* name, NSObject* object){ [weakSelf resultsChanged: (SpCSearch*)object]; } withId: @"Search"];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    [delegate startLocationManager];
    [delegate.data addListener:^(NSString* name, NSObject* object){ [weakSelf searchesChanged: (SpCData*)object]; } withId: @"Searches"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    return 1;
    //SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    //NSLog(@"number of searches for %@: %d", [self side], [delegate.data numberOfSearchesFor:[self side]]);
    //return 1 + [delegate.data numberOfSearchesFor:[self side]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0 == section? 1 : 1 + [self.search.results count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)path
{
    NSLog(@"tableView:cellForRowAtIndexPath:(%d, %d)", int(path.section), int(path.row));
    if (0 == path.section) {
        UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"SearchField"];
        UIView* view = [cell.contentView viewWithTag:0];
        if (view && 1 == view.subviews.count) {
            self.searchBar = [view.subviews objectAtIndex:0];
            self.searchBar.text = self.search.query;
        }
        return cell;
    }
    else if (1 == path.section) {
        UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"Search" forIndexPath:path];
#if 0
        UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"Result" forIndexPath:path];
        SpCResult* result = [self.search.results objectAtIndex:path.row];
        UIView* view = [cell.contentView viewWithTag:0];
        if (view && 1 == view.subviews.count) {
            UILabel* label = [view.subviews objectAtIndex:0];
            label.text = result.value;
        }
        else {
            cell.textLabel.text = result.value;
        }
#endif
        return cell;
    }
    else {
        UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"DeleteSearch"];
        return cell;
    }
    
    return nil;
}

- (IBAction)deleteSearch:(id)sender {
    NSLog(@"Delete Search was clicked: search=%@", self.search.id);
    UINavigationController *navController = [self navigationController];
    [navController popViewControllerAnimated: YES];
    SpCAppDelegate* delegate = (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
    [delegate.data deleteSearch:self.search];
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
    NSLog(@"search bar button clicked: '%@' '%@'", searchBar.text, [self side]);
    if (0 < searchBar.text.length) {
        NSLog(@"calling function on search: %@", self.search? @"non-NIL": @"NIL");
        if (self.search == Nil) {
            self.search = [[SpCSearch alloc] init];
        }
        [self.search updateQueryWith: searchBar.text forSide: [self side]];
    }
    [searchBar resignFirstResponder];

}

- (void)searchesChanged:(SpCData*)data
{
    NSLog(@"searches changed");
    //NSIndexSet* indices = [[NSIndexSet alloc] initWithIndex:1];
    //[self.tableView reloadSections:indices withRowAnimation: UITableViewRowAnimationNone];
}

- (void)resultsChanged:(SpCSearch*)search
{
    NSLog(@"results changed");
    //NSIndexSet* indices = [[NSIndexSet alloc] initWithIndex:1];
    //[self.tableView reloadSections:indices withRowAnimation: UITableViewRowAnimationNone];

}

@end
