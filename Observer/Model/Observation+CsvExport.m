//
//  Observation+CsvExport.m
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Observation+CsvExport.h"
#import "Observation+Location.h"
#import "ObserverModel.h"
#import "AKRFormatter.h"

@implementation Observation (CsvExport)

+(NSString *)csvHeaderForFeature:(ProtocolFeature *)feature
{
    NSMutableString *header = [NSMutableString new];
    for (NSAttributeDescription *attribute in feature.attributes) {
        NSString *cleanName = [attribute.name stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
        [header appendFormat:@"%@,",cleanName];
    }
    
    [header appendString:@"Timestamp_UTC,Timestamp_Local,Year,Day_of_Year,Feature_Latitude,Feature_Longitude,Observer_Latitude,Observer_Longitude,Datum"];

    //Always write both map and angle Distance data, to make the server side processing easier
    //if (feature.allowedLocations.allowsMapLocations) {
        [header appendString:@",Map_Name,Map_Author,Map_Date"];
    //}
    //if (feature.allowedLocations.allowsAngleDistanceLocations) {
        [header appendString:@",Angle,Distance,Perp_Meters"];
    //}
    return header;
}

-(NSString *)asCsvForFeature:(ProtocolFeature *)feature
{
    NSMutableString *csv = [NSMutableString new];
    //get the variable attributes based on the feature type
    for (NSAttributeDescription *attribute in feature.attributes) {
        id value = [self valueForKey:attribute.name];
        [csv appendFormat:@"%@,",(value ? value : @"")];
    }

    CLLocationCoordinate2D featureLocation = [self locationOfFeature];
    CLLocationCoordinate2D observerLocation = [self locationOfObserver];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSInteger year = [gregorian components:NSYearCalendarUnit fromDate:self.timestamp].year;
    NSUInteger dayOfYear = [gregorian ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:self.timestamp];
    [csv appendFormat:@"%@,%@,%ld,%lu,%0.6f,%0.6f,%0.6f,%0.6f,WGS84",
     [AKRFormatter utcIsoStringFromDate:self.timestamp],
     [AKRFormatter localIsoStringFromDate:self.timestamp],(long)year,(unsigned long)dayOfYear,
     featureLocation.latitude, featureLocation.longitude,
     observerLocation.latitude, observerLocation.longitude];

    //if (feature.allowedLocations.allowsMapLocations) {
        if (!self.gpsPoint && self.adhocLocation.map) {
            [csv appendFormat:@",%@,%@,%@", self.adhocLocation.map.name, self.adhocLocation.map.author, self.adhocLocation.map.date];
        } else {
            [csv appendString:@",,,"];
        }
    //}
    //if (feature.allowedLocations.allowsAngleDistanceLocations) {
        if (self.angleDistanceLocation) {
            LocationAngleDistance *angleDistance = [[LocationAngleDistance alloc] initWithDeadAhead:self.angleDistanceLocation.direction
                                                                                    protocolFeature:feature
                                                                                      absoluteAngle:self.angleDistanceLocation.angle
                                                                                           distance:self.angleDistanceLocation.distance];

            [csv appendFormat:@",%@,%@,%g", angleDistance.angle, angleDistance.distance, angleDistance.perpendicularMeters];
        } else {
            [csv appendString:@",,,"];
        }
    //}
    return csv;
}

@end
