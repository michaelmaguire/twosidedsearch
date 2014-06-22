//
//  SpCMapViewController.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 18/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import "SpCMapViewController.h"
#import <CoreLocation/CoreLocation.h>

@interface SpCMapViewController ()

@end

@implementation SpCMapViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    CLLocationCoordinate2D position = [self.search getPosition];

    self.mapView.showsUserLocation = YES;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(position, 5000, 500);
    [self.mapView setRegion: region animated: NO];
    [self.mapView addAnnotation: self.search];
    [self.mapView addAnnotations: self.search.results];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

// ----------------------------------------------------------------------------

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>) annotation {
    MKPinAnnotationView *rc = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"pin"];
    rc.canShowCallout = YES;

    if ([annotation.subtitle isEqualToString:@"drag to relocate"]) {
        rc.pinColor = MKPinAnnotationColorPurple;
        rc.draggable = YES;
    }
    return rc;
}

@end
