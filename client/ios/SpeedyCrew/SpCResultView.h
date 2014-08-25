//
//  SpCResultView.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 26/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@interface SpCResultView : NSObject<MKAnnotation>

@property (nonatomic, readonly)       CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly, copy) NSString*              title;
@property (nonatomic, readonly, copy) NSString*              subtitle;
@property (nonatomic, readonly, copy) NSString*              fingerprint;
@property (nonatomic, readonly, copy) NSString*              identity;
@property (nonatomic, readonly, copy) NSString*              query;
@property (nonatomic, readonly, copy) NSString*              email;
@property (readonly)                  NSString*              key;
@property (readonly)                  int                    rowid;

+ (SpCResultView*)makeWithKey:(NSString*)key;
+ (SpCResultView*)makeWithRow:(int)row;
- (SpCResultView*)initWithKey:(NSString*)key;

@end
