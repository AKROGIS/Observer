//
//  GpsPoint+CsvExport.h
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GpsPoint.h"

@interface GpsPoint (CsvExport)

+ (NSString *)csvHeader;

@property (nonatomic, readonly, copy) NSString *asCSV;

@end
