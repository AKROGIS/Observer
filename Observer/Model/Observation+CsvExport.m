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
    NSMutableString *header = [NSMutableString stringWithString:@"timestamp,datum,feature_latitude,feature_longitude,observer_latitude,observer_longitude,map_name,map_author,map_date,angle,distance"];
    for (NSAttributeDescription *attribute in feature.attributes) {
        [header appendString:@","];
        NSString *cleanName = [attribute.name stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
        [header appendString:cleanName];
    }
    return header;
}

-(NSString *)asCsvForFeature:(ProtocolFeature *)feature
{
    CLLocationCoordinate2D featureLocation = [self locationOfFeature];
    CLLocationCoordinate2D observerLocation = [self locationOfObserver];
    NSMutableString *csv = [NSMutableString stringWithFormat:@"%@,WGS84,%0.6f,%0.6f,%0.6f,%0.6f",
                            [AKRFormatter utcIsoStringFromDate:[self timestamp]],
                            featureLocation.latitude, featureLocation.longitude,
                            observerLocation.latitude, observerLocation.longitude];

    if (!self.gpsPoint && self.adhocLocation.map) {
        [csv appendFormat:@",%@,%@,%@", self.adhocLocation.map.name, self.adhocLocation.map.author, self.adhocLocation.map.date];
    } else {
        [csv appendString:@",,,"];
    }

    if (self.angleDistanceLocation) {
        LocationAngleDistance *angleDistance = [[LocationAngleDistance alloc] initWithDeadAhead:self.angleDistanceLocation.direction
                                                                                protocolFeature:feature
                                                                                  absoluteAngle:self.angleDistanceLocation.angle
                                                                                       distance:self.angleDistanceLocation.distance];

        [csv appendFormat:@",%@,%@", angleDistance.angle, angleDistance.distance];
    } else {
        [csv appendString:@",,"];
    }

    //get the variable attributes based on the feature type
    for (NSAttributeDescription *attribute in feature.attributes) {
        [csv appendString:@","];
        id value = [self valueForKey:attribute.name];
        if (value) {
            [csv appendFormat:@"%@",value];
        }
    }
    return csv;
}

@end
