//
//  SpCResult.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 02/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpCResult : NSObject

@property NSString* id;
@property NSString* value;

- (SpCResult*)initWithId: (NSString*)id value: (NSString*) value;

@end
