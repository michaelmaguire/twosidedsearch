//
//  SpCSearchListener.h
//  SpeedyCrew
//
//  Created by Dietmar Kühl on 02/01/2014.
//  Copyright (c) 2014 Dietmar Kühl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SpCSearch.h"

@interface SpCSearchListener : NSObject

- (void)resultsChanged:(NSObject*)search;

@end
