//
//  Survey+Mapping.h
//  Observer
//
//  Created by Regan Sarwas on 5/14/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Survey.h"
#import "ObserverModel.h"

@interface Survey (Mapping)

// Layer Methods
- (NSDictionary *)graphicsLayersByName;
//- (AGSGraphicsLayer *)graphicsLayerForGpsPoints;
//- (AGSGraphicsLayer *)graphicsLayerForMissionProperties;
//- (AGSGraphicsLayer *)graphicsLayerForTracksLogObserving:(BOOL)observing;
- (AGSGraphicsLayer *)graphicsLayerForObservation:(Observation *)observation;
- (AGSGraphicsLayer *)graphicsLayerForFeature:(ProtocolFeature *)feature;

- (BOOL)isSelectableLayerName:(NSString *)layerName;
- (NSManagedObject *)entityOnLayerNamed:(NSString *)layerName atTimestamp:(NSDate *)timestamp;
//- (ProtocolFeature *)featureOnLayerNamed:(NSString *)layerName;

// State Control
- (BOOL)isReadyToRecord;
- (void)startRecording;
- (BOOL)isRecording;
- (Mission *)currentMission;
- (void)stopRecording;

- (void)setMap:(Map *)map;
- (void)clearMap;

//FIXME: This smells ad. maybe I shouldn't do the drawing.
//FIXME: I am also drawing the observation in the VC, need to combine
- (void)setMapViewSpatialReference:(AGSSpatialReference *)spatialReference;
- (void)clearMapMapViewSpatialReference;

// GPS Methods
- (GpsPoint *)addGpsPointAtLocation:(CLLocation *)location;
- (BOOL)hasGpsPoint;
- (GpsPoint *)lastGpsPoint;

//TrackLogs
- (TrackLogSegment *)startObserving;
- (BOOL)isObserving;
- (void)stopObserving;
- (TrackLogSegment *)startNewTrackLogSegment;
//- (TrackLogSegment *)lastTrackLogSegment;
//- (NSDictionary *)currentEnvironmentValues;
//- (void)updateTrackLogSegment:(TrackLogSegment *)trackLogSegment attributes:(NSDictionary *)attributes;
//- (TrackLogSegment *)trackLogSegmentAtTimestamp:(NSDate *)timestamp;
//- (NSArray *)trackLogSegments;

// Observations
- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint;
- (Observation *)createObservation:(ProtocolFeature *)feature AtMapLocation:(AGSPoint *)mapPoint;
- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint withAngleDistanceLocation:(LocationAngleDistance *)angleDistance;
- (void)updateAdhocLocation:(AdhocLocation *)adhocLocation withMapPoint:(AGSPoint *)mapPoint;



// Misc - rethink

//- (BOOL)saveNewMissionPropertyEditAttributes:(BOOL)edit;

- (void)loadGraphics;

- (void)deleteObject:(NSManagedObject *)object;


@end
