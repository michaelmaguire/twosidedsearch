//
//  SpCInvitesController.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 05/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SpCInvitesController : UIViewController<UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSMutableArray       *invites;

@end
