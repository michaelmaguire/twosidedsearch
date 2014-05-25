//
//  SpCMapViewController.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 18/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearchView.h"
#import <UIKit/UIKit.h>

@interface SpCMapViewController : UIViewController
@property (weak, nonatomic) IBOutlet UINavigationItem *backButton;
@property SpCSearchView* search;

@end
