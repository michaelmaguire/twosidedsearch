//
//  SpCProfile.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 25/08/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpCProfile : NSObject

@property (readonly)                  NSString* fingerprint;
@property (nonatomic, readonly, copy) NSString* real_name;
@property (nonatomic, readonly, copy) NSString* username;
@property (nonatomic, readonly, copy) NSString* email;
@property (nonatomic, readonly, copy) NSString* message;

+ (SpCProfile*)makeWithFingerprint:(NSString*)fingerprint;
- (SpCProfile*)initWithFingerprint:(NSString*)fingerprint;

@end
