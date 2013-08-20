//
//  MissionProperty.h
//  Observer
//
//  Created by Regan Sarwas on 8/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AdhocLocation, AttributeSet, GpsPoint, Mission;

@interface MissionProperty : NSManagedObject

@property (nonatomic, retain) AdhocLocation *adhocLocation;
@property (nonatomic, retain) AttributeSet *attributeSet;
@property (nonatomic, retain) GpsPoint *gpsPoint;
@property (nonatomic, retain) Mission *mission;

@end
