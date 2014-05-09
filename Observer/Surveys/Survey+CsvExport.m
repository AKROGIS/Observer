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

@end
