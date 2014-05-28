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
    
    [header appendString:@"timestamp_utc,timestamp_local,year,day_of_year,feature_latitude,feature_longitude,observer_latitude,observer_longitude,datum"];
    
    if (feature.allowedLocations.allowsMapLocations) {
        [header appendString:@",map_name,map_author,map_date"];
    }
    if (feature.allowedLocations.allowsAngleDistanceLocations) {
        [header appendString:@",angle,distance,perp_meters"];
    }
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
    [csv appendFormat:@"%@,%@,%d,%d,%0.6f,%0.6f,%0.6f,%0.6f,WGS84",
     [AKRFormatter utcIsoStringFromDate:self.timestamp],
     [AKRFormatter localIsoStringFromDate:self.timestamp],year,dayOfYear,
     featureLocation.latitude, featureLocation.longitude,
     observerLocation.latitude, observerLocation.longitude];

    if (feature.allowedLocations.allowsMapLocations) {
        if (!self.gpsPoint && self.adhocLocation.map) {
            [csv appendFormat:@",%@,%@,%@", self.adhocLocation.map.name, self.adhocLocation.map.author, self.adhocLocation.map.date];
        } else {
            [csv appendString:@",,,"];
        }
    }
    if (feature.allowedLocations.allowsAngleDistanceLocations) {
        if (self.angleDistanceLocation) {
            LocationAngleDistance *angleDistance = [[LocationAngleDistance alloc] initWithDeadAhead:self.angleDistanceLocation.direction
                                                                                    protocolFeature:feature
                                                                                      absoluteAngle:self.angleDistanceLocation.angle
                                                                                           distance:self.angleDistanceLocation.distance];

            [csv appendFormat:@",%@,%@,%g", angleDistance.angle, angleDistance.distance, angleDistance.perpendicularMeters];
        } else {
            [csv appendString:@",,,"];
        }
    }
    return csv;
}

@end
