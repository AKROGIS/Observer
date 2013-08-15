//
//  AngleDistanceLocations.h
//  Observer
//
//  Created by Regan Sarwas on 8/14/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Observations;

@interface AngleDistanceLocations : NSManagedObject

@property (nonatomic) double angle;
@property (nonatomic) double direction;
@property (nonatomic) double distance;
@property (nonatomic, retain) Observations *observation;

@end
