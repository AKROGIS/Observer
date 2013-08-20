//
//  Mission.h
//  Observer
//
//  Created by Regan Sarwas on 8/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GpsPoint, MissionProperty, Observation;

@interface Mission : NSManagedObject

@property (nonatomic, retain) NSSet *gpsPoints;
@property (nonatomic, retain) NSSet *missionProperties;
@property (nonatomic, retain) NSSet *observations;
@end

@interface Mission (CoreDataGeneratedAccessors)

- (void)addGpsPointsObject:(GpsPoint *)value;
- (void)removeGpsPointsObject:(GpsPoint *)value;
- (void)addGpsPoints:(NSSet *)values;
- (void)removeGpsPoints:(NSSet *)values;

- (void)addMissionPropertiesObject:(MissionProperty *)value;
- (void)removeMissionPropertiesObject:(MissionProperty *)value;
- (void)addMissionProperties:(NSSet *)values;
- (void)removeMissionProperties:(NSSet *)values;

- (void)addObservationsObject:(Observation *)value;
- (void)removeObservationsObject:(Observation *)value;
- (void)addObservations:(NSSet *)values;
- (void)removeObservations:(NSSet *)values;

@end
