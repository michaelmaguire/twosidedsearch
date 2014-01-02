//
//  SpCViewController.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SpCSearch.h"
#import "SpCSearchListener.h"

@interface SpCViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (strong, nonatomic) SpCSearch            *currentSearch;
@property (strong, nonatomic) NSMutableArray       *searches;
@property (strong, nonatomic) NSMutableArray       *actions;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *queryField;

@end
