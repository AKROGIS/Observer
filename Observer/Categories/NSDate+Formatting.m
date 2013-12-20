//
//  NSDate+Formatting.m
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "NSDate+Formatting.h"

@implementation NSDate (Formatting)

- (NSString *)stringWithMediumDateTimeFormat
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDoesRelativeDateFormatting:YES];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    return [dateFormatter stringFromDate:self];
}

- (NSString *)stringWithMediumDateFormat
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDoesRelativeDateFormatting:YES];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    return [dateFormatter stringFromDate:self];
}

- (NSString *)stringWithMediumTimeFormat
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDoesRelativeDateFormatting:YES];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    return [dateFormatter stringFromDate:self];
}

- (NSString *)stringWithRelativeTimeFormat
{
    NSTimeInterval seconds = [self timeIntervalSinceNow];
    if (seconds < 60) {
        return @"Just Now";
    }
    if (seconds < 120) {
        return @"1 Minute";
    }
    if (seconds < 3600) {
        return [NSString stringWithFormat:@"%d Minutes",(int)floor(seconds/60)];
    }
    if (seconds < 7200) {
        return @"1 Hour";
    }
    return [NSString stringWithFormat:@"%d Hours",(int)floor(seconds/3600)];
}

- (BOOL)isToday
{
    return [[self dateOnly] isEqualToDate:[[NSDate date] dateOnly]];
}

- (NSDate *)dateOnly
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *components = [cal components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:self];
    return [cal dateFromComponents:components];
}

@end
