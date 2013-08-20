//
//  Missions.h
//  Observer
//
//  Created by Regan Sarwas on 8/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GpsPoints, MissionProperties, Observations;

@interface Missions : NSManagedObject

@property (nonatomic, retain) NSSet *gpsPoints;
@property (nonatomic, retain) NSSet *missionProperties;
@property (nonatomic, retain) NSSet *observations;
@end

@interface Missions (CoreDataGeneratedAccessors)

- (void)addGpsPointsObject:(GpsPoints *)value;
- (void)removeGpsPointsObject:(GpsPoints *)value;
- (void)addGpsPoints:(NSSet *)values;
- (void)removeGpsPoints:(NSSet *)values;

- (void)addMissionPropertiesObject:(MissionProperties *)value;
- (void)removeMissionPropertiesObject:(MissionProperties *)value;
- (void)addMissionProperties:(NSSet *)values;
- (void)removeMissionProperties:(NSSet *)values;

- (void)addObservationsObject:(Observations *)value;
- (void)removeObservationsObject:(Observations *)value;
- (void)addObservations:(NSSet *)values;
- (void)removeObservations:(NSSet *)values;

@end
