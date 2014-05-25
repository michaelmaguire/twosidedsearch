//
//  SpCMapViewController.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 18/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCSearchView.h"
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface SpCMapViewController : UIViewController
@property (weak, nonatomic) IBOutlet UINavigationItem *backButton;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property SpCSearchView* search;

@end
