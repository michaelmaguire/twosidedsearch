//
//  SpCAppDelegate.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SpCData.h"

@interface SpCAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property SpCData*                      data;

@end
