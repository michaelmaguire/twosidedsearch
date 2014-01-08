//
//  SpCData.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 30/12/2013.
//  Copyright (c) 2013 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpCData : NSObject

@property NSString*       identity;
@property NSMutableArray* searches;

- (SpCData*)init;
- (void)updateSetting:(NSString*)name with:(NSString*)value;

@end
