//
//  AKRFormatter.m
//  Observer
//
//  Created by Regan Sarwas on 12/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AKRFormatter.h"

@implementation AKRFormatter

+ (NSDate *)dateFromISOString:(NSString *)dateString
{
    if (!dateString) {
        return nil;
    }
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [NSDateFormatter new];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd"];
        [dateFormatter setLenient:YES];
    });
    return [dateFormatter dateFromString:dateString];
}

+ (NSString *)stringFromBytes:(long long)bytes
{
    static NSByteCountFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSByteCountFormatter new];
    });
    return [formatter stringFromByteCount:bytes];
}

+ (NSString *)stringWith3SigFigsFromDouble:(double)number
{
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.usesGroupingSeparator = YES;
        formatter.maximumSignificantDigits = 3;
    });
    return [formatter stringFromNumber:[NSNumber numberWithDouble:number]];
}

+ (NSString *)stringWith4SigFigsFromDouble:(double)number
{
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.usesGroupingSeparator = YES;
        formatter.maximumSignificantDigits = 4;
    });
    return [formatter stringFromNumber:[NSNumber numberWithDouble:number]];
}


@end
