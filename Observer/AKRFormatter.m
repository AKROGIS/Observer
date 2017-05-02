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
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"yyyy'-'MM'-'dd";
        [dateFormatter setLenient:YES];
    });
    return [dateFormatter dateFromString:dateString];
}

+ (NSString *)descriptiveStringFromDate:(NSDate *)date
{
    if (!date) {
        return nil;
    }
    static NSDateFormatter *outDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        outDateFormatter = [NSDateFormatter new];
        outDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        outDateFormatter.dateFormat = @"MMM' 'd', 'y' at 'HH':'mm':'ss.SS' 'zzz";
    });
    return [outDateFormatter stringFromDate:date];
}

+ (NSString *)utcIsoStringFromDate:(NSDate *)date
{
    if (!date) {
        return nil;
    }
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [NSDateFormatter new];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'";
    });
    return [dateFormatter stringFromDate:date];
}

+ (NSString *)localIsoStringFromDate:(NSDate *)date
{
    if (!date) {
        return nil;
    }
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [NSDateFormatter new];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS' 'z";
    });
    return [dateFormatter stringFromDate:date];
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
    return [formatter stringFromNumber:@(number)];
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
    return [formatter stringFromNumber:@(number)];
}


@end
