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
     return @"timestamp,latitude,longitude,datum,error_radius_m,course,speed_mps,altitude_m,vert_error_m";
}

- (NSString *)asCSV
{
    return [NSString stringWithFormat:@"%@,%0.6f,%0.6f,WGS84,%g,%g,%g,%g,%g", [AKRFormatter utcIsoStringFromDate:self.timestamp], self.latitude, self.longitude, self.horizontalAccuracy, self.course, self.speed, self.altitude, self.verticalAccuracy];
}

@end
