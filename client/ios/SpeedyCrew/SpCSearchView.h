//
//  SpCSearchView.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 14/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@interface SpCSearchView : NSObject<MKAnnotation>

@property (nonatomic, readonly)       CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly, copy) NSString*              title;
@property (nonatomic, readonly, copy) NSString*              subtitle;
@property (readonly) NSString*               id;
@property (readonly) NSString*               side;
@property            bool                    expanded;
@property            NSMutableArray*         results;

+ (SpCSearchView*)makeWithId:(NSString*)id andSide:(NSString*)side;
- (SpCSearchView*)initWithId:(NSString*)id andSide:(NSString*)side;
- (int)updateResults;
- (CLLocationCoordinate2D)getPosition;
- (void)setCoordinate:(CLLocationCoordinate2D)position;

@end
