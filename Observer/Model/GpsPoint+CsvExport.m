//
//  GpsPoint+CsvExport.m
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "GpsPoint+CsvExport.h"
#import "AKRFormatter.h"

@implementation GpsPoint (CsvExport)

+ (NSString *)csvHeader
{
     return @"altitude,course,datum,horizontalAccuracy,latitude,longitude,speed,timestamp,verticalAccuracy";
}

- (NSString *)asCSV
{
    return [NSString stringWithFormat:@"%g,%g,WGS84,%g,%0.5f,%0.5f,%g,%@,%g", self.altitude, self.course, self.horizontalAccuracy, self.latitude, self.longitude, self.speed, [AKRFormatter isoStringFromDate:self.timestamp], self.verticalAccuracy];
}

@end
