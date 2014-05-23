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
    NSMutableString *header = [NSMutableString stringWithString:@"start_utc,end_utc,start_local,end_local,start_lat,start_lon,end_lat,end_lon,datum,duration_sec,length_m,year,day_of_year,observing"];
    for (NSAttributeDescription *attribute in protocol.missionFeature.attributes) {
        [header appendString:@","];
        NSString *cleanName = [attribute.name stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
        [header appendString:cleanName];
    }
    return header;
}

- (NSString *)asCsvForProtocol:(SProtocol *)protocol
{
    GpsPoint *start = (GpsPoint *)[self.gpsPoints firstObject];
    GpsPoint *end = (GpsPoint *)[self.gpsPoints lastObject];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSInteger year = [gregorian components:NSYearCalendarUnit fromDate:start.timestamp].year;
    NSUInteger dayOfYear = [gregorian ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:start.timestamp];
    NSMutableString *csv;
    csv = [NSMutableString stringWithFormat:@"%@,%@,%@,%@,%0.6f,%0.6f,%0.6f,%0.6f,WGS84,%0.1f,%0.2f,%d,%u,%@",
           [AKRFormatter utcIsoStringFromDate:start.timestamp], [AKRFormatter utcIsoStringFromDate:end.timestamp],
           [AKRFormatter localIsoStringFromDate:start.timestamp], [AKRFormatter localIsoStringFromDate:end.timestamp],
           start.latitude, start.longitude, end.latitude, end.longitude,
           [end.timestamp timeIntervalSinceDate:start.timestamp], self.length, year, dayOfYear, (self.missionProperty.observing ? @"Yes" : @"No")];

    //get the variable attributes based on the feature type
    for (NSAttributeDescription *attribute in protocol.missionFeature.attributes) {
        [csv appendString:@","];
        id value = [self.missionProperty valueForKey:attribute.name];
        if (value) {
            [csv appendFormat:@"%@",value];
        }
    }
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
