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


- (NSString *)csvForTrackLogsSince:(NSDate *)timestamp
{
    NSMutableString *csv = [NSMutableString stringWithString:[TrackLogSegment csvHeaderForProtocol:self.protocol]];
    [csv appendString:@"\n"];
    for (TrackLogSegment *tracklog in [self trackLogSegmentsSince:timestamp]) {
        [csv appendString:[tracklog asCsvForProtocol:self.protocol]];
        [csv appendString:@"\n"];
    }
    return csv;
}


@end
