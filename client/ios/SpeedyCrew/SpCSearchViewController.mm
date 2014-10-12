//
//  SpCSearchViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearchViewController.h"
#import "SpCSearchView.h"
#import "SpCResultView.h"
#import "SpCMapViewController.h"
#import "SpCMatchTableViewController.h"
#import "SpCAppDelegate.h"
#import "SpCDatabase.h"
#import "SpCData.h"
#import <SDWebImage/UIImageView+WebCache.h>

#include "Database.h"
#include <stdexcept>

@interface SpCSearchViewController ()
@property NSMutableArray* searches;
@end

@implementation SpCSearchViewController

// ----------------------------------------------------------------------------

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
    NSString* id = [NSString stringWithFormat:@"%@-SearchViewController", self.side];
    [delegate.data addListener:^(NSString* name, NSObject* object){ [weakSelf reloadSearches]; } withId: id];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    NSLog(@"%@-SearchView received memory warning", self.side);
}

// ----------------------------------------------------------------------------
#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UIView* view = (UIButton*)sender;
    long tag = view.tag;
    if (0 <= tag && tag < [self.searches count]) {
        SpCMapViewController* map = [segue destinationViewController];
        map.search = [self.searches objectAtIndex: tag];
    }
    else {
        SpCMatchTableViewController* match = [segue destinationViewController];
        match.result = (SpCResultView*)[SpCResultView makeWithRow:-tag];
        match.profile = [SpCProfile makeWithFingerprint: match.result.fingerprint];
        NSLog(@"profile: real_name=%@ username=%@ email=%@ message=%@", match.profile.real_name, match.profile.username, match.profile.email, match.profile.message);
    }
}

// ----------------------------------------------------------------------------
// search bar handling
//-dk:TODO update a search with an existing ID and unlink the search upon clear

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    //-dk:TODO do something useful?
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    SpCData* data = [SpCAppDelegate instance].data;
    [data addSearchWithText:searchBar.text forSide:self.side];
    [searchBar resignFirstResponder];

}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    NSLog(@"search bar cancel button clicked");
    [searchBar resignFirstResponder];
}
   
// ----------------------------------------------------------------------------
#pragma mark - Table view data source

- (void)basicReloadSearches
{
    SpeedyCrew::Database* db = [SpCDatabase getDatabase];
    std::string side([self.side UTF8String]);
    [self.searches removeAllObjects];
    try {
        std::vector<std::string> searches(db->queryColumn("select id from search where side='" + side + "'"));
        for (std::vector<std::string>::const_iterator it(searches.begin()), end(searches.end()); it != end; ++it) {
            [self.searches addObject: [SpCSearchView makeWithId:[NSString stringWithUTF8String: it->c_str()] andSide:self.side]];
        }
    }
    catch (std::runtime_error const& ex) { // eat database errors
    }
}

- (void)reloadSearches
{
    [self basicReloadSearches];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    if ([self.searches count] == 0) {
        [self basicReloadSearches];
    }
    return [self.searches count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    SpCSearchView* search = [self.searches objectAtIndex: section];
    int result = [search updateResults];
    return 1 + (search.expanded? result: 0);
}

- (void)onExpand: (id)sender
{
    UITapGestureRecognizer* gesture = (UITapGestureRecognizer*)sender;
    long section = gesture.view.tag;
    if (section < [self.searches count]) {
        SpCSearchView* search = [self.searches objectAtIndex: section];
        bool value = !search.expanded;
        search.expanded = value;
        [self.tableView reloadData];
    }
}

// ----------------------------------------------------------------------------

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path {
    return path.row? NO: YES;
}

- (void)tableView:(UITableView *)tableView
        commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
        forRowAtIndexPath:(NSIndexPath *)path {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSLog(@"deleting the search of section %ld", (long)path.section);
        if (path.section < [self.searches count]) {
            SpCSearchView* search = [self.searches objectAtIndex:path.section];
            SpCData* data = [SpCAppDelegate instance].data;
            [data deleteSearch:search.id];
        }    
    }
}

// ----------------------------------------------------------------------------

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)path
{
    SpCSearchView* search = [self.searches objectAtIndex: path.section];
    UITableViewCell* cell = nil;
    if (path.row == 0) {
        cell = [tv dequeueReusableCellWithIdentifier:@"Search"];
        cell.tag = path.section;
        cell.textLabel.text = search.title;

        cell.imageView.userInteractionEnabled = YES;
        cell.imageView.tag = path.section;
        UITapGestureRecognizer* tapped = [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(onExpand:)];
        tapped.numberOfTapsRequired = 1;
        [cell.imageView addGestureRecognizer:tapped];
        cell.imageView.image = [UIImage imageNamed:(search.expanded? @"Minus": @"Plus")];
    }
    else {
        cell = [tv dequeueReusableCellWithIdentifier:@"Search Result"];
        SpCResultView* result = [search.results objectAtIndex: path.row - 1];

        NSLog(@"rowid=%ld", result.rowid);
        cell.tag = -result.rowid;
        cell.textLabel.text = result.identity;
        cell.detailTextLabel.text = result.query;

        NSString* gravatar = [SpCData gravatarURLForEmail:result.email];
        if (gravatar) {
            [cell.imageView sd_setImageWithURL:[NSURL URLWithString:gravatar]
                           placeholderImage:[UIImage imageNamed:@"Unknown"]];
        }
    }
    return cell;
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

// ----------------------------------------------------------------------------
@end
