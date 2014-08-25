//
//  SpCMatchTableViewController.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 24/08/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SpCResultView.h"
#import "SpCProfile.h"

@interface SpCMatchTableViewController : UITableViewController

- (IBAction)onToggleView:(id)sender;
@property SpCResultView* result;
@property SpCProfile*    profile;

@end
