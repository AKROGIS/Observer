//
//  TrackLogSegment.m
//  Observer
//
//  Created by Regan Sarwas on 5/15/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "AGSPoint+AKRAdditions.h"
#import "AKRFormatter.h"
#import "CommonDefines.h"
#import "GpsPoint+Location.h"
#import "NSString+csvEscape.h"
#import "TrackLogSegment.h"

@interface TrackLogSegment ()

@property (nonatomic, strong, readwrite) AGSPolylineBuilder *polylineBuilder;
@property (nonatomic, strong, readwrite) NSMutableArray *points; //of GpsPoints

@end

@implementation TrackLogSegment

- (instancetype)initWithMissionProperty:(MissionProperty *)missionProperty
{
    if (!missionProperty || !missionProperty.gpsPoint) {
        return nil;
    }
    self = [super init];
    if (self) {
        _missionProperty = missionProperty;
        _points = [NSMutableArray arrayWithObject:missionProperty.gpsPoint];
        AGSPoint *mapPoint = [AGSPoint pointWithCLLocationCoordinate2D:missionProperty.gpsPoint.locationOfGps]; //WGS84
        _polylineBuilder = [AGSPolylineBuilder polylineBuilderWithPoints:@[mapPoint]];
    }
    return self;
}

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
            value = ((NSString *)value).csvEscape;
        }
        [csv appendFormat:@"%@,",(value ? value : @"")];
    }

    GpsPoint *start = (GpsPoint *)self.points.firstObject;
    GpsPoint *end = (GpsPoint *)self.points.lastObject;
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSInteger year = [gregorian components:NSCalendarUnitYear fromDate:start.timestamp].year;
    NSUInteger dayOfYear = [gregorian ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitYear forDate:start.timestamp];
    [csv appendFormat:@"%@,%@,%@,%ld,%lu,%@,%@,%0.2f,%0.6f,%0.6f,%0.6f,%0.6f,WGS84,%0.1f",
     (self.missionProperty.observing ? @"Yes" : @"No"),
     [AKRFormatter utcIsoStringFromDate:start.timestamp], [AKRFormatter localIsoStringFromDate:start.timestamp], (long)year, (unsigned long)dayOfYear,
     [AKRFormatter utcIsoStringFromDate:end.timestamp], [AKRFormatter localIsoStringFromDate:end.timestamp], [end.timestamp timeIntervalSinceDate:start.timestamp],
     start.latitude, start.longitude, end.latitude, end.longitude, self.length];

    return csv;
}

- (AGSPolyline *)polyline
{
    return (AGSPolyline *)[AGSGeometryEngine simplifyGeometry:[self.polylineBuilder toGeometry]];
}

- (void)addGpsPoint:(GpsPoint *)gpsPoint
{
    if (gpsPoint == nil) {
        return;
    }
    [self.points addObject:gpsPoint];
    AGSPoint *point = [AGSPoint pointWithCLLocationCoordinate2D:gpsPoint.locationOfGps]; //WGS84
    [self.polylineBuilder addPoint:point];
}

- (double)length
{
    return [AGSGeometryEngine lengthOfGeometry:self.polyline];  //Meters
}

- (NSTimeInterval)duration
{
    GpsPoint *start = (GpsPoint *)self.points.firstObject;
    GpsPoint *end = (GpsPoint *)self.points.lastObject;
    return [end.timestamp timeIntervalSinceDate:start.timestamp];
}

//- (NSArray *)gpsPoints
//{
//    return [self.points copy];
//}

- (BOOL)hasOnlyOnePoint
{
    return self.points.count == 1;
}

- (NSUInteger)pointCount
{
    return self.points.count;
}

@end
