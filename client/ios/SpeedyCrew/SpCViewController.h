//
//  SpCViewController.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "SpCSearch.h"

@interface SpCViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) SpCSearch            *currentSearch;
@property (strong, nonatomic) NSMutableArray       *searches;
@property (strong, nonatomic) NSMutableArray       *actions;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end
