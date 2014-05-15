//
//  SpCSearchView.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 14/05/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpCSearchView : NSObject

@property (readonly) NSString*        id;
@property (readonly) NSString*        side;
@property            bool             expanded;
@property            NSMutableArray*  results;

+ (SpCSearchView*)makeWithId:(NSString*)id andSide:(NSString*)side;
- (SpCSearchView*)initWithId:(NSString*)id andSide:(NSString*)side;
- (int)updateResults;

@end
