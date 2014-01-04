//
//  SpCDatabase.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 04/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpCDatabase : NSObject

+ (SpCDatabase*) database;
- (NSString*) querySetting: (NSString*)name;
- (NSString*) querySetting: (NSString*)name withDefault:(NSString*)def;

@end
