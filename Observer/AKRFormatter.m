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

+ (NSString *)longDateFromString:(NSDate *)date
{
    if (!date) {
        return nil;
    }
    static NSDateFormatter *outDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        outDateFormatter = [NSDateFormatter new];
        [outDateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [outDateFormatter setDateFormat:@"MMM' 'd', 'y' at 'HH':'mm':'ss.SS' 'zzz"];
    });
    return [outDateFormatter stringFromDate:date];
}

+ (NSString *)isoStringFromDate:(NSDate *)date
{
    if (!date) {
        return nil;
    }
    static NSDateFormatter *out2DateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        out2DateFormatter = [NSDateFormatter new];
        [out2DateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [out2DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [out2DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"];
    });
    return [out2DateFormatter stringFromDate:date];
}

+ (NSString *)stringFromBytes:(unsigned long long)bytes
{
    static NSByteCountFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSByteCountFormatter new];
    });
    //drop the sign, because of an inconsistency in Apple's API
    long long bytes2 = (long long)bytes;
    if (bytes2 < 0) {
        return @"Bigger than you can imagine";
    } else {
        return [formatter stringFromByteCount:(long long)bytes];
    }
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
