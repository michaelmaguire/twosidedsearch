//
//  SpCMessageViewController.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 28/09/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SpCMessageViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UIView *view;
@property NSString* crewId;

@end
