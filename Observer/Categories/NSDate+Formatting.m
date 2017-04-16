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
    if (seconds < 30) {
        return NSLocalizedString(@"Just Now", @"Relative time for less than 30 seconds");
    }
    if (seconds < 90) {
        return NSLocalizedString(@"1 Minute", @"Relative time for 30 to 90 seconds");
    }
    if (seconds < 3570) {
        NSString *units = NSLocalizedString(@"Minutes", @"Relative time for 2 to 59 minutes");
        double minutes = floor((seconds/60.0)+0.5);
        return [NSString stringWithFormat:@"%d %@",(int)minutes, units];
    }
    if (seconds < 5400) {
        return NSLocalizedString(@"1 Hour", @"Relative time for 59.5 minutes to 1.5 hours");
    }
    NSString *units = NSLocalizedString(@"Hours", @"Relative time for 1.5 to 24 hours");
    double hours = floor((seconds/3600.0)+0.5);
    return [NSString stringWithFormat:@"%d %@",(int)hours, units];
}

- (BOOL)isToday
{
    return [[self dateOnly] isEqualToDate:[[NSDate date] dateOnly]];
}

- (NSDate *)dateOnly
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *components = [cal components:(NSCalendarUnit)(NSCalendarUnitEra|NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay) fromDate:self];
    return [cal dateFromComponents:components];
}

@end
