//
//  AdhocLocations.h
//  Observer
//
//  Created by Regan Sarwas on 8/15/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Observations;

@interface AdhocLocations : NSManagedObject

@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic) NSDate *timestamp;
@property (nonatomic, retain) Observations *observation;

@end
