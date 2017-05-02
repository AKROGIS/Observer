//
//  TrackLogSegment.h
//  Observer
//
//  Created by Regan Sarwas on 5/15/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <Foundation/Foundation.h>
#import "MissionProperty.h"
#import "SProtocol.h"
#import "GpsPoint.h"

@interface TrackLogSegment : NSObject

// NOTE: The Designated Initializer is not public, THIS CLASS CANNOT BE SUB-CLASSED
- (instancetype)init __attribute__((unavailable("Must use initWithMissionProperty: instead.")));
- (instancetype)initWithMissionProperty:(MissionProperty *)missionProperty;

@property (nonatomic, strong, readonly) MissionProperty *missionProperty;
//@property (nonatomic, strong, readonly) NSArray *gpsPoints;
@property (nonatomic, strong, readonly) AGSPolyline *polyline;
@property (nonatomic, readonly) BOOL hasOnlyOnePoint;
@property (nonatomic, readonly) NSUInteger pointCount;
@property (nonatomic, readonly) double length; //in meters
@property (nonatomic, readonly) NSTimeInterval duration; //in seconds


+ (NSString *)csvHeaderForProtocol:(SProtocol *)protocol;

- (NSString *)asCsvForProtocol:(SProtocol *)protocol;

- (void)addGpsPoint:(GpsPoint *)gpsPoint;

@end
