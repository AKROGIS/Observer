//
//  AKRFormatter.h
//  Observer
//
//  Created by Regan Sarwas on 12/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AKRFormatter : NSObject

+ (NSDate *)dateFromISOString:(NSString *)dateString;
+ (NSString *)longDateFromString:(NSDate *)date;
+ (NSString *)stringFromBytes:(unsigned long long)bytes;
+ (NSString *)stringWith3SigFigsFromDouble:(double)number;
+ (NSString *)stringWith4SigFigsFromDouble:(double)number;

@end
