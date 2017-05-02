//
//  NSDate+Formatting.h
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Formatting)

@property (nonatomic, readonly, copy) NSString *stringWithMediumDateTimeFormat;
@property (nonatomic, readonly, copy) NSString *stringWithMediumDateFormat;
@property (nonatomic, readonly, copy) NSString *stringWithMediumTimeFormat;
@property (nonatomic, readonly, copy) NSString *stringWithRelativeTimeFormat;

@property (nonatomic, getter=isToday, readonly) BOOL today;

@end
