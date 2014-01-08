//
//  SpCSearchViewController.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SpCSearch.h"

@interface SpCSearchViewController : UITableViewController<UISearchBarDelegate>

@property SpCSearch* search;
@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end
