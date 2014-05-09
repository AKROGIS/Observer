//
//  Survey+CsvExport.h
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Survey.h"

@interface Survey (CsvExport)

- (NSString *)csvForGpsPointsMatching:(NSPredicate *)predicate;
- (NSString *)csvForGpsPointsSince:(NSDate *)timestamp;

@end
