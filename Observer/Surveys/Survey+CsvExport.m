//
//  Survey+CsvExport.m
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Survey+CsvExport.h"
#import "ObserverModel.h"
#import "GpsPoint+CsvExport.h"
#import "Observation+CsvExport.h"
#import "AKRFormatter.h"

@implementation Survey (CsvExport)

- (NSString *)csvForGpsPointsMatching:(NSPredicate *)predicate
{
    NSMutableString *csv = [NSMutableString stringWithString:[GpsPoint csvHeader]];
    [csv appendString:@"\n"];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:kTimestampKey ascending:YES]];
    request.predicate = predicate;
    NSArray *results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    for (GpsPoint *gpsPoint in results) {
        [csv appendString:[gpsPoint asCSV]];
        [csv appendString:@"\n"];
    }
    return csv;
}

- (NSString *)csvForGpsPointsSince:(NSDate *)timestamp
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"timestamp >= %@",timestamp];
    return [self csvForGpsPointsMatching:predicate];
}


- (NSString *)csvForFeature:(ProtocolFeature *)feature matching:(NSPredicate *)predicate
{
    NSMutableString *csv = [NSMutableString stringWithString:[Observation csvHeaderForFeature:feature]];
    [csv appendString:@"\n"];
    NSString *entityName = [NSString stringWithFormat:@"%@%@",kObservationPrefix,feature.name];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
    //TODO: sort descriptor is gpsPoint.timestamp || adhocLocation.timestamp
    //    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:kTimestampKey ascending:YES]];
    request.predicate = predicate;
    NSArray *results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    for (Observation *observation in results) {
        [csv appendString:[observation asCsvForFeature:feature]];
        [csv appendString:@"\n"];
    }
    return csv;
}

- (NSString *)csvForFeature:(ProtocolFeature *)feature since:(NSDate *)timestamp
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"gpsPoint.timestamp >= %@ || adhocLocation.timestamp >= %@",timestamp];
    return [self csvForFeature:feature matching:predicate];
}


- (NSDictionary *)csvForFeaturesMatching:(NSPredicate *)predicate
{
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    for (ProtocolFeature *feature in self.protocol.features) {
        dictionary[feature.name] = [self csvForFeature:feature matching:predicate];
    }
    return dictionary;
}

- (NSDictionary *)csvForFeaturesSince:(NSDate *)timestamp
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"gpsPoint.timestamp >= %@ || adhocLocation.timestamp >= %@",timestamp];
    return [self csvForFeaturesMatching:predicate];
}

- (NSString *)csvForTrackLogMatching:(NSPredicate *)predicate
{
    NSMutableString *csv = [NSMutableString stringWithString:@"start_utc,start_local,start_lat,start_lon,end_local,end_utc,end_lat,end_lon,datum,length_m,year,day_of_year,observing"];
    for (NSAttributeDescription *attribute in self.protocol.missionFeature.attributes) {
        [csv appendString:@","];
        NSString *cleanName = [attribute.name stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
        [csv appendString:cleanName];
    }
    [csv appendString:@"\n"];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:kTimestampKey ascending:YES]];
    request.predicate = predicate;
    NSArray *results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    GpsPoint *firstPoint = nil;
    GpsPoint *previousPoint = nil;
    Mission *mission = nil;
    MissionProperty *missionProperty = nil;
    for (GpsPoint *gpsPoint in results) {
        if (!firstPoint) {
            firstPoint = gpsPoint;
            missionProperty = gpsPoint.missionProperty;
            mission = gpsPoint.mission;
            continue;
        }
        if (mission != gpsPoint.mission && previousPoint) {
            [csv appendString:[self csvFroTrackLogStart:firstPoint end:previousPoint props:firstPoint.missionProperty]];
            [csv appendString:@"\n"];
            firstPoint = gpsPoint;
            missionProperty = gpsPoint.missionProperty;
            mission = gpsPoint.mission;
            continue;
        }
        if (missionProperty != gpsPoint.missionProperty) {
            [csv appendString:[self csvFroTrackLogStart:firstPoint end:gpsPoint props:firstPoint.missionProperty]];
            [csv appendString:@"\n"];
            firstPoint = gpsPoint;
            missionProperty = gpsPoint.missionProperty;
        }
        previousPoint = gpsPoint;
    }
    return csv;
}

- (NSString *)csvFroTrackLogStart:(GpsPoint *)start end:(GpsPoint *)end props:(MissionProperty *)props
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSInteger year = [gregorian components:NSYearCalendarUnit fromDate:start.timestamp].year;
    NSUInteger dayOfYear = [gregorian ordinalityOfUnit:NSDayCalendarUnit inUnit:NSYearCalendarUnit forDate:start.timestamp];
    NSMutableString *csv;
    csv = [NSMutableString stringWithFormat:@"%@,%@,%0.6f,%0.6f,%@,%@,%0.6f,%0.6f,WGS84,%g,%d,%u,%@",
            [AKRFormatter isoStringFromDate:start.timestamp], @"", start.latitude, start.longitude,
            [AKRFormatter isoStringFromDate:end.timestamp], @"", end.latitude, end.longitude,
            0.0, year, dayOfYear, (props.observing ? @"Yes" : @"No")];

    //get the variable attributes based on the feature type
    for (NSAttributeDescription *attribute in self.protocol.missionFeature.attributes) {
        [csv appendString:@","];
        id value = [props valueForKey:attribute.name];
        if (value) {
            [csv appendFormat:@"%@",value];
        }
    }
    return csv;
}

- (NSString *)csvForTrackLogSince:(NSDate *)timestamp
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"gpsPoint.timestamp >= %@ || adhocLocation.timestamp >= %@",timestamp];
    return [self csvForTrackLogMatching:predicate];
}


@end
