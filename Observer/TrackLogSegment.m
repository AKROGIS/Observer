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

@implementation TrackLogSegment

+ (NSString *)csvHeaderForProtocol:(SProtocol *)protocol
{
    NSMutableString *header = [NSMutableString new];
    for (NSAttributeDescription *attribute in protocol.missionFeature.attributes) {
        NSString *cleanName = [attribute.name stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
        [header appendFormat:@"%@,",cleanName];
    }
    [header appendString:@"observing,start_utc,start_local,year,day_of_year,end_utc,end_local,duration_sec,start_lat,start_lon,end_lat,end_lon,datum,length_m"];
    return header;
}

- (NSString *)asCsvForProtocol:(SProtocol *)protocol
{
    NSMutableString *csv = [NSMutableString new];
    //get the variable attributes based on the feature type
    for (NSAttributeDescription *attribute in protocol.missionFeature.attributes) {
        id value = [self.missionProperty valueForKey:attribute.name];
        [csv appendFormat:@"%@,",(value ? value : @"")];
    }

    GpsPoint *start = (GpsPoint *)[self.gpsPoints firstObject];
    GpsPoint *end = (GpsPoint *)[self.gpsPoints lastObject];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSInteger year = [gregorian components:NSYearCalendarUnit fromDate:start.timestamp].year;
    NSUInteger dayOfYear = [gregorian ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:start.timestamp];
    [csv appendFormat:@"%@,%@,%@,%d,%u,%@,%@,%0.2f,%0.6f,%0.6f,%0.6f,%0.6f,WGS84,%0.1f",
     (self.missionProperty.observing ? @"Yes" : @"No"),
     [AKRFormatter utcIsoStringFromDate:start.timestamp], [AKRFormatter localIsoStringFromDate:start.timestamp], year, dayOfYear,
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

// private methods
- (double)length
{
    return [[AGSGeometryEngine defaultGeometryEngine] shapePreservingLengthOfGeometry:self.polyline inUnit:AGSSRUnitMeter];
}

@end
