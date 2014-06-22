//
//  SpCSearchViewController.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SpCSearchViewController : UIViewController<UISearchBarDelegate>

@property NSString*  side;
@property (strong, nonatomic) IBOutlet UITableView *tableView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
- (void)viewDidLoad;

@end
