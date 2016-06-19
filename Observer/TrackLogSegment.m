//
//  TrackLogSegment.m
//  Observer
//
//  Created by Regan Sarwas on 5/15/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "TrackLogSegment.h"
#import "ObserverModel.h"
#import "AKRFormatter.h"
#import "NSString+csvEscape.h"

@implementation TrackLogSegment

+ (NSString *)csvHeaderForProtocol:(SProtocol *)protocol
{
    NSMutableString *header = [NSMutableString new];
    for (NSAttributeDescription *attribute in protocol.missionFeature.attributes) {
        NSString *cleanName = [attribute.name stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
        [header appendFormat:@"%@,",cleanName];
    }
    [header appendString:@"Observing,Start_UTC,Start_Local,Year,Day_of_Year,End_UTC,End_Local,Duration_sec,Start_Latitude,Start_Longitude,End_Latitude,End_Longitude,Datum,Length_m"];
    return header;
}

- (NSString *)asCsvForProtocol:(SProtocol *)protocol
{
    NSMutableString *csv = [NSMutableString new];
    //get the variable attributes based on the feature type
    for (NSAttributeDescription *attribute in protocol.missionFeature.attributes) {
        id value = [self.missionProperty valueForKey:attribute.name];
        if ([value isKindOfClass:[NSString class]]) {
            value = [((NSString *)value) csvEscape];
        }
        [csv appendFormat:@"%@,",(value ? value : @"")];
    }

    GpsPoint *start = (GpsPoint *)[self.gpsPoints firstObject];
    GpsPoint *end = (GpsPoint *)[self.gpsPoints lastObject];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSInteger year = [gregorian components:NSYearCalendarUnit fromDate:start.timestamp].year;
    NSUInteger dayOfYear = [gregorian ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:start.timestamp];
    [csv appendFormat:@"%@,%@,%@,%ld,%lu,%@,%@,%0.2f,%0.6f,%0.6f,%0.6f,%0.6f,WGS84,%0.1f",
     (self.missionProperty.observing ? @"Yes" : @"No"),
     [AKRFormatter utcIsoStringFromDate:start.timestamp], [AKRFormatter localIsoStringFromDate:start.timestamp], (long)year, (unsigned long)dayOfYear,
     [AKRFormatter utcIsoStringFromDate:end.timestamp], [AKRFormatter localIsoStringFromDate:end.timestamp], [end.timestamp timeIntervalSinceDate:start.timestamp],
     start.latitude, start.longitude, end.latitude, end.longitude, self.length];

    return csv;
}

- (AGSPolyline *)polyline {
    AGSSpatialReference *wgs84 = [AGSSpatialReference wgs84SpatialReference];
    AGSMutablePolyline *pline = [[AGSMutablePolyline alloc] initWithSpatialReference:wgs84];
    [pline addPathToPolyline];
    for (GpsPoint *gpsPoint in self.gpsPoints) {
        [pline addPointToPath:[AGSPoint pointFromLocation:gpsPoint.locationOfGps spatialReference:wgs84]];
    }
    return (AGSPolyline *)[[AGSGeometryEngine defaultGeometryEngine] simplifyGeometry:pline];
}

- (double)length
{
    return [[AGSGeometryEngine defaultGeometryEngine] shapePreservingLengthOfGeometry:self.polyline inUnit:AGSSRUnitMeter];
}

- (NSTimeInterval)duration
{
    GpsPoint *start = (GpsPoint *)[self.gpsPoints firstObject];
    GpsPoint *end = (GpsPoint *)[self.gpsPoints lastObject];
    return [end.timestamp timeIntervalSinceDate:start.timestamp];
}

@end
