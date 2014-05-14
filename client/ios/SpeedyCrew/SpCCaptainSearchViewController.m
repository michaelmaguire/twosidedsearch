//
//  SpCCaptainSearchViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 11/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCCaptainSearchViewController.h"
#import "SpCSearchView.h"

@interface SpCCaptainSearchViewController ()
@property NSArray* searches;
@end

@implementation SpCCaptainSearchViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSLog(@"SpcCaptainSearchViewController being initialized");
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"tableView is %s", self.tableView == Nil? "Nil": "not Nil");
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    NSLog(@"SpcCaptainSearchViewController creating searches");
    self.searches = [[NSArray alloc] initWithObjects:
                           [SpCSearchView makeWithId:@"id1" andSide:@"Provide"],
                           [SpCSearchView makeWithId:@"id2" andSide:@"Provide"],
                           [SpCSearchView makeWithId:@"id3" andSide:@"Provide"],
                           Nil];
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
    NSLog(@"search text changed: '%@'", searchText);
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSLog(@"search bar button clicked: '%@'", searchBar.text);
#if 0
    NSLog(@"search bar button clicked: '%@' '%@'", searchBar.text, [self side]);
    if (0 < searchBar.text.length) {
        NSLog(@"calling function on search: %@", self.search? @"non-NIL": @"NIL");
        if (self.search == Nil) {
            self.search = [[SpCSearch alloc] init];
        }
        [self.search updateQueryWith: searchBar.text forSide: [self side]];
    }
#endif
    [searchBar resignFirstResponder];

}

// ----------------------------------------------------------------------------
#pragma mark - search table handling

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    return 3;
}

- (int)getFirstTagOf:(UIView*)view
{
    while (view != Nil && view.tag <= 0) {
        view = [view superview];
    }
    return view == Nil? 0: view.tag;
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
    NSLog(@"header clicked: %d", [self getFirstTagOf: sender]);
}

- (IBAction)onHeaderNavigationClicked:(id)sender
{
    NSLog(@"header navigation clicked: %d", [self getFirstTagOf: sender]);
}

- (UIView*)tableView:(UITableView*)tv viewForHeaderInSection:(NSInteger)section
{
    UITableViewCell* header = [tv dequeueReusableCellWithIdentifier:@"Header"];
    header.tag = section + 1;
    UIButton* expand = (UIButton*)[header viewWithTag: -1001];
    SpCSearchView* search = [self.searches objectAtIndex: section];
    NSLog(@"search in section %d is %s", section, search.expanded? "expanded": "collapsed");
    [expand setTitle: (search.expanded? @"-": @"+") forState:UIControlStateNormal];
    return header;
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)section
{
    return 30.0f; //-dk:TODO should probably determine the height of the label
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    SpCSearchView* search = [self.searches objectAtIndex: section];
    int result = search.expanded? 3: 0;
    NSLog(@"rows in section %d: %d", section, result);
    return result;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)path
{
    NSLog(@"tableView:cellForRowAtIndexPath:(%d, %d)", path.section, path.row);
    if (0 == path.row) {
        UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"Search Header"];
        return cell;
    }
    else {
        UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"Search Result"];
        return cell;
    }
    
    return nil;
}

// ----------------------------------------------------------------------------

@end
