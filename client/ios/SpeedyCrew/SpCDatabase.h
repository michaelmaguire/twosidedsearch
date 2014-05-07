//
//  SpCDatabase.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 04/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>

namespace SpeedyCrew { class Database; };

@interface SpCDatabase : NSObject

+ (SpCDatabase*) database;
+ (SpeedyCrew::Database*) getDatabase;

// - (int) queryInteger;

- (int) queryVector:(NSString*)query;

- (NSString*) querySetting: (NSString*)name;
- (void) updateSetting:(NSString*)name with:(NSString*)value;

- (int) numberSearchesFor:(NSString*)side;
- (void) addSearch:(NSString*)text forSide:(NSString*)side withId:(NSString*) id;
- (void) removeSearch:(NSString*)id;
@end
