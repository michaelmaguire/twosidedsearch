//
//  SpCAppDelegate.m
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 03/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import "SpCAppDelegate.h"

@implementation SpCAppDelegate {
    CLLocationManager* locationManager;
}

+ (SpCAppDelegate*)instance
{
    return (((SpCAppDelegate*) [UIApplication sharedApplication].delegate));
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"application launched");
    self.data = [[SpCData alloc] init];
    [self.data updateSearches];
    [self startLocationManager];
    return YES;
}

- (void)startLocationManager
{
    if (locationManager == nil) {
        locationManager = [[CLLocationManager alloc] init];
        locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
#if 1
        //-dk:TODO enable location updates
        [locationManager startUpdatingLocation];
#else
        //-dk:TODO use automatic updates
        self.data.longitude = -0.15001;
        self.data.latitude  = 51.5;
#endif
    }
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"AppDelegate locationManager didFailWithError: %@", error);
    UIAlertView *errorAlert = [[UIAlertView alloc]
                               initWithTitle:@"Error" message:@"Failed to Get Your Location" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [errorAlert show];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    //-dk:TODO move the location update to the data object itself...?
    if (newLocation != nil
        && (newLocation.coordinate.longitude != oldLocation.coordinate.longitude
            || newLocation.coordinate.latitude != oldLocation.coordinate.latitude)) {
        self.data.longitude = newLocation.coordinate.longitude;
        self.data.latitude  = newLocation.coordinate.latitude;
        NSLog(@"updated location: (%f, %f)", self.data.longitude, self.data.latitude);
    }
}
@end
