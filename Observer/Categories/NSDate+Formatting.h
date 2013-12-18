//
//  NSDate+Formatting.h
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Formatting)

- (NSString *)stringWithMediumDateTimeFormat;
- (NSString *)stringWithMediumDateFormat;
- (NSString *)stringWithMediumTimeFormat;

- (BOOL)isToday;

@end
