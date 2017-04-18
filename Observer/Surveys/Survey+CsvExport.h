//
//  Survey+CsvExport.h
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Survey.h"

@interface Survey (CsvExport)

- (NSString *)csvForGpsPointsMatching:(NSPredicate *)predicate;
- (NSString *)csvForGpsPointsSince:(NSDate *)timestamp;

- (NSString *)csvForFeature:(ProtocolFeature *)feature matching:(NSPredicate *)predicate;
- (NSString *)csvForFeature:(ProtocolFeature *)feature since:(NSDate *)timestamp;

- (NSDictionary *)csvForFeaturesMatching:(NSPredicate *)predicate;
- (NSDictionary *)csvForFeaturesSince:(NSDate *)timestamp;

- (NSString *)csvForTrackLogsSince:(NSDate *)timestamp;

@end
