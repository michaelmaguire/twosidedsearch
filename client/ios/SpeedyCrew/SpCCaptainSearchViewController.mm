//
//  SpCCaptainSearchViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 11/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCCaptainSearchViewController.h"
#import "SpCSearchView.h"
#import "SpCAppDelegate.h"
#import "SpCDatabase.h"
#import "SpCData.h"
#include "Database.h"

@interface SpCCaptainSearchViewController ()
@property NSMutableArray* searches;
@end

@implementation SpCCaptainSearchViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    //-dk:TODO verify if this can ever be called for a non-initial view
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.searches = [[NSMutableArray alloc] init];

    SpCAppDelegate* delegate = [SpCAppDelegate instance];
    __weak typeof(self) weakSelf = self;
    [delegate.data addListener:^(NSString* name, NSObject* object){ [weakSelf reloadSearches]; } withId: @"SpCCaptainSearchViewController"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

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
// search bar handling

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    //-dk:TODO do something useful?
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSLog(@"search bar button clicked: '%@'", searchBar.text);
    SpCData* data = [SpCAppDelegate instance].data;
    [data addSearchWithText:searchBar.text forSide:@"PROVIDE"];
    [searchBar resignFirstResponder];

}

// ----------------------------------------------------------------------------
#pragma mark - search table handling

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    if ([self.searches count] == 0) {
        [self basicReloadSearches];
    }
    return [self.searches count];
}

- (void)basicReloadSearches
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::vector<std::string> searches(db->queryColumn("select id from searches where side='PROVIDE'"));
    [self.searches removeAllObjects];
    for (std::vector<std::string>::const_iterator it(searches.begin()), end(searches.end()); it != end; ++it) {
        [self.searches addObject: [SpCSearchView makeWithId:[NSString stringWithFormat:@"%s", it->c_str()] andSide:@"PROVIDE"]];
    }
}

- (void)reloadSearches
{
    [self basicReloadSearches];
    [self.tableView reloadData];
}

- (UIView*)tableView:(UITableView*)tv viewForHeaderInSection:(NSInteger)section
{
    UITableViewCell* header = [tv dequeueReusableCellWithIdentifier:@"Header"];
    header.tag = section + 1;
    UIButton* expand = (UIButton*)[header viewWithTag: -1001];
    SpCSearchView* search = [self.searches objectAtIndex: section];
    NSLog(@"search in section %ld is %s", long(section), search.expanded? "expanded": "collapsed");
    [expand setTitle: (search.expanded? @"-": @"+") forState:UIControlStateNormal];

    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string text = db->query<std::string>("select search from searches where id='" + db->escape([search.id UTF8String]) + "';");
    UIButton* title = (UIButton*)[header viewWithTag: -1002];
    [title setTitle: [NSString stringWithFormat:@"%s", text.c_str()] forState:UIControlStateNormal];
    return header;
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)section
{
    return 30.0f; //-dk:TODO should probably determine the height of the label
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    SpCSearchView* search = [self.searches objectAtIndex: section];
    int result = [search updateResults];
    NSLog(@"rows in section %ld: %d", long(section), result);
    return search.expanded? result: 0;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)path
{
    //if (0 == path.row) {
    //    UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"Search Header"];
    //    return cell;
    //}
    //else {
    UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"Search Result"];
    UILabel* label = (UILabel*)[cell viewWithTag: -1004];
    SpCSearchView* search = [self.searches objectAtIndex: path.section];
    [label setText:[search.results objectAtIndex: path.row]];
    NSLog(@"tableView:cellForRowAtIndexPath:(%ld, %ld)=%@", long(path.section), long(path.row), [search.results objectAtIndex: path.row]);
    return cell;
    //}
}

// ----------------------------------------------------------------------------
#pragma mark - handling of header button events

- (int)getFirstTagOf:(UIView*)view
{
    while (view != Nil && view.tag <= 0) {
        view = [view superview];
    }
    return view == Nil? 0: int(view.tag);
}

- (IBAction)onHeaderToggleClicked:(id)sender
{
    UIButton* button = sender;
    int section = [self getFirstTagOf: sender] - 1;
    bool expand = [button.titleLabel.text isEqualToString: @"+"];
    NSLog(@"header toggle clicked: %d %s", section, expand? "expanding": "collapsing");
    [button setTitle: (expand? @"-": @"+") forState:UIControlStateNormal];
    SpCSearchView* search = [self.searches objectAtIndex: section];
    search.expanded = expand;
    [self.tableView reloadData];
}

- (IBAction)onHeaderClicked:(id)sender
{
    NSLog(@"header clicked: %ld", long([self getFirstTagOf: sender]));
}

- (IBAction)onHeaderNavigationClicked:(id)sender
{
    NSLog(@"header navigation clicked: %ld", long([self getFirstTagOf: sender]));
}

// ----------------------------------------------------------------------------

@end
