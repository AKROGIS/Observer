//
//  Survey+Mapping.m
//  Observer
//
//  Created by Regan Sarwas on 5/14/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Survey+Mapping.h"

@implementation Survey (Mapping)

//while these look like instance variables, since we are in a category, they are actually class variables,
// i.e. there is only one value for the entire class.
//This actually works, since there is only one active survey at a time.

MapReference *_currentMapEntity;
Mission *_currentMission;
GpsPoint *_lastGpsPoint;
AGSSpatialReference *_mapViewSpatialReference;
BOOL _isObserving;
NSMutableArray * _trackLogSegments;
id<SurveyLocationDelegate> _locationDelegate;

#pragma mark - Layer Methods

- (NSDictionary *)graphicsLayersByName
{
    static NSDictionary *_graphicsLayersByName = nil;
    if (!_graphicsLayersByName) {
        NSMutableDictionary *graphicsLayers = [NSMutableDictionary new];

        //gps points
        AGSGraphicsLayer *graphicsLayer = [[AGSGraphicsLayer alloc] init];
        AGSMarkerSymbol *symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[UIColor blueColor]];
        [symbol setSize:CGSizeMake(6,6)];
        [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:symbol]];
        graphicsLayers[kGpsPointEntityName] = graphicsLayer;

        //Observations
        for (ProtocolFeature *feature in self.protocol.features) {
            graphicsLayer = [[AGSGraphicsLayer alloc] init];
            [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:feature.symbology.agsMarkerSymbol]];
            graphicsLayers[feature.name] = graphicsLayer;
        }

        //Mission Properties
        ProtocolMissionFeature *missionFeature = self.protocol.missionFeature;
        graphicsLayer = [[AGSGraphicsLayer alloc] init];
        [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:missionFeature.symbology.agsMarkerSymbol]];
        graphicsLayers[kMissionPropertyEntityName] = graphicsLayer;

        //Track logs observing
        NSString * name = [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOn];
        graphicsLayer = [[AGSGraphicsLayer alloc] init];
        [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:missionFeature.observingSymbology.agsLineSymbol]];
        graphicsLayers[name] = graphicsLayer;

        //Track logs not observing
        name = [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOff];
        graphicsLayer = [[AGSGraphicsLayer alloc] init];
        [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:missionFeature.notObservingSymbology.agsLineSymbol]];
        graphicsLayers[name] = graphicsLayer;

        _graphicsLayersByName = [graphicsLayers copy];
    }
    return _graphicsLayersByName;
}

- (AGSGraphicsLayer *)graphicsLayerForObservation:(Observation *)observation
{
    NSString * name = [observation.entity.name stringByReplacingOccurrencesOfString:kObservationPrefix withString:@""];
    return self.graphicsLayersByName[name];
}

- (AGSGraphicsLayer *)graphicsLayerForFeature:(ProtocolFeature *)feature
{
    if ([feature isKindOfClass:[ProtocolMissionFeature class]]) {
        return self.graphicsLayersByName[kMissionPropertyEntityName];
    } else {
        return self.graphicsLayersByName[feature.name];
    }
}

- (BOOL)isSelectableLayerName:(NSString *)layerName
{
    for (NSString *badName in @[kGpsPointEntityName,
                                [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOn],
                                [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOff]]) {
        if ([layerName isEqualToString:badName]) {
            return NO;
        }
    }
    return YES;
}

- (NSManagedObject *)entityOnLayerNamed:(NSString *)layerName atTimestamp:(NSDate *)timestamp
{
    if (!layerName || !timestamp) {
        return nil;
    }
    if (![self isSelectableLayerName:layerName]) {
        return nil;
    }

    //Deal with ESRI graphic date bug
    NSDate *start = [timestamp dateByAddingTimeInterval:-0.01];
    NSDate *end = [timestamp dateByAddingTimeInterval:+0.01];
    NSString *name = [self entityNameFromLayerName:layerName];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:name];
    request.predicate = [NSPredicate predicateWithFormat:@"(%@ <= gpsPoint.timestamp AND gpsPoint.timestamp <= %@) || (%@ <= adhocLocation.timestamp AND adhocLocation.timestamp <= %@)",start,end,start,end];
    NSArray *results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    return (NSManagedObject *)[results lastObject]; // will return nil if there was an error, or no results
}




#pragma mark - Layer Methods - private

- (AGSGraphicsLayer *)graphicsLayerForGpsPoints
{
    return self.graphicsLayersByName[kGpsPointEntityName];
}

- (AGSGraphicsLayer *)graphicsLayerForMissionProperties
{
    return self.graphicsLayersByName[kMissionPropertyEntityName];
}

- (AGSGraphicsLayer *)graphicsLayerForTracksLogObserving:(BOOL)observing
{
    NSString *name = [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, (observing ? kTrackOn : kTrackOff)];
    return self.graphicsLayersByName[name];
}

- (NSString *)entityNameFromLayerName:(NSString *)layerName {
    NSString *entityName = nil;
    if ([layerName isEqualToString:kGpsPointEntityName] || [layerName isEqualToString:kMissionPropertyEntityName]) {
        entityName = layerName;
    } else if ([layerName hasPrefix:kMissionPropertyEntityName]) {
        entityName = nil;
    } else {
        entityName = [NSString stringWithFormat:@"%@%@",kObservationPrefix, layerName];
    }
    return entityName;
}





#pragma mark - State Methods

- (void)startRecording
{
    if(!self.isReady) {
        return;
    }
    _currentMission = [NSEntityDescription insertNewObjectForEntityForName:kMissionEntityName
                                                    inManagedObjectContext:self.document.managedObjectContext];
    [[self trackLogSegments] addObject:[self startNewTrackLogSegment]];
}

- (BOOL)isRecording
{
    return _currentMission != nil;
}

- (Mission *)currentMission
{
    return _currentMission;
}

- (void)stopRecording
{
    if (self.isObserving) {
        [self stopObserving];
    }
    _currentMission = nil;
}

- (void)setMap:(Map *)map
{
    // try to fetch it, otherwise create it.
    //AKRLog(@"Looking for %@ in coredata",map);
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kMapEntityName];

    request.predicate = [NSPredicate predicateWithFormat:@"name == %@ AND author == %@ AND date == %@",
                         map.title, map.author, map.date];
    NSArray *results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    _currentMapEntity = [results firstObject];
    if(!_currentMapEntity) {
        //AKRLog(@"  Map not found, creating new CoreData Entity");
        _currentMapEntity = [NSEntityDescription insertNewObjectForEntityForName:kMapEntityName inManagedObjectContext:self.document.managedObjectContext];
        _currentMapEntity.name = map.title;
        _currentMapEntity.author = map.author;
        _currentMapEntity.date = map.date;
    }
}

- (void)clearMap
{
    _currentMapEntity = nil;
}

- (void)setMapViewSpatialReference:(AGSSpatialReference *)spatialReference
{
    _mapViewSpatialReference = spatialReference;
}

- (void)clearMapMapViewSpatialReference
{
    _mapViewSpatialReference = nil;
}

- (void)setLocationDelegate:(id<SurveyLocationDelegate>)locationDelegate
{
    _locationDelegate = locationDelegate;
}

- (id<SurveyLocationDelegate>)locationDelegate
{
    return _locationDelegate;
}




#pragma mark - State Methods - private

- (MapReference *)currentMapEntity
{
    return _currentMapEntity;
}

- (AGSSpatialReference *)mapViewSpatialReference
{
    return _mapViewSpatialReference;
}




#pragma mark - GPS Methods

- (GpsPoint *)addGpsPointAtLocation:(CLLocation *)location
{
    if ([self isNewLocation:location]) {
        GpsPoint *oldPoint = self.lastGpsPoint;
        GpsPoint *gpsPoint = [self createGpsPoint:location];
        if (gpsPoint) {
            _lastGpsPoint = gpsPoint;
            [[self lastTrackLogSegment].gpsPoints addObject:gpsPoint];
            [self drawGpsPoint:gpsPoint];
        }
        if (oldPoint && gpsPoint) {
            [self drawLineFor:[self lastTrackLogSegment].missionProperty from:oldPoint to:gpsPoint];
        }
        return gpsPoint;
    } else {
        return self.lastGpsPoint;
    }
}

- (GpsPoint *)lastGpsPoint
{
    return _lastGpsPoint;
}




#pragma mark - GPS Methods - private

- (BOOL)isNewLocation:(CLLocation *)location
{
    if (!self.lastGpsPoint)
        return YES;
    //0.0001 deg in latitude is about 18cm (<1foot) assuming a mean radius of 6371m, and less in longitude away from the equator.
    if (fabs(location.coordinate.latitude - self.lastGpsPoint.latitude) > 0.0001)
        return YES;
    if (fabs(location.coordinate.longitude - self.lastGpsPoint.longitude) > 0.0001)
        return YES;
    //TODO: is 10 seconds a good default?  do I want a user setting? this gets called a lot, so I don't want to slow down with a lookup
    if ([location.timestamp timeIntervalSinceDate:self.lastGpsPoint.timestamp] > 10.0)
        return YES;
    return NO;
}

- (GpsPoint *)createGpsPoint:(CLLocation *)gpsData
{
    //AKRLog(@"Creating GpsPoint, Lat = %f, lon = %f, timestamp = %@", gpsData.coordinate.latitude, gpsData.coordinate.longitude, gpsData.timestamp);
    if (!gpsData.timestamp) {
        AKRLog(@"Can't save a GPS Point without a timestamp!");
        return nil; //TODO: added for testing on simulator, remove for production
    }
    if (self.lastGpsPoint && [self.lastGpsPoint.timestamp timeIntervalSinceDate:gpsData.timestamp] == 0) {
        return self.lastGpsPoint;
    }
    GpsPoint *gpsPoint = [NSEntityDescription insertNewObjectForEntityForName:kGpsPointEntityName
                                                       inManagedObjectContext:self.document.managedObjectContext];
    if (!gpsPoint) {
        AKRLog(@"Could not create a Gps Point in Core Data");
        return nil;
    }
    if (!self.currentMission) {
        AKRLog(@"Can not create a Gps Point without a mission");
        return nil;
    }

    gpsPoint.mission = self.currentMission;
    gpsPoint.altitude = gpsData.altitude;
    gpsPoint.course = gpsData.course;
    gpsPoint.horizontalAccuracy = gpsData.horizontalAccuracy;
    //TODO: CLLocation only guarantees that lat/long are double.  Our Coredata constraint may fail.
    gpsPoint.latitude = gpsData.coordinate.latitude;
    gpsPoint.longitude = gpsData.coordinate.longitude;
    gpsPoint.speed = gpsData.speed;
    gpsPoint.timestamp = gpsData.timestamp; // ? gpsData.timestamp : [NSDate date]; //TODO: added for testing on simulator, remove for production
    gpsPoint.verticalAccuracy = gpsData.verticalAccuracy;
    return gpsPoint;
}




#pragma mark - TrackLog Methods - private

- (TrackLogSegment *)startObserving
{
    _isObserving = YES;
    TrackLogSegment *newTrackLog = [self startNewTrackLogSegment];
    [[self trackLogSegments] addObject:newTrackLog];
    return newTrackLog;
}

- (BOOL)isObserving
{
    return _isObserving;
}

- (void)stopObserving
{
    _isObserving = NO;
    [[self trackLogSegments] addObject:[self startNewTrackLogSegment]];
}

- (TrackLogSegment *)startNewTrackLogSegment
{
    MissionProperty *missionProperty = [self createMissionProperty];
    TrackLogSegment *trackLog = [TrackLogSegment new];
    trackLog.missionProperty = missionProperty;
    GpsPoint *firstGpsPoint = missionProperty.gpsPoint;
    if (firstGpsPoint) {
        trackLog.gpsPoints = [NSMutableArray arrayWithObject:firstGpsPoint];
    }
    return trackLog;
}

- (TrackLogSegment *)lastTrackLogSegment
{
    return [[self trackLogSegments] lastObject];
}

/*
- (NSDictionary *)currentEnvironmentValues
{
    //TODO: implement
    return nil;
}

- (void)updateTrackLogSegment:(TrackLogSegment *)trackLogSegment attributes:(NSDictionary *)attributes
{
    //TODO: implement
}

- (TrackLogSegment *)trackLogSegmentAtTimestamp:(NSDate *)timestamp
{
    //TODO: implement
    return nil;
}
*/

- (NSMutableArray *)trackLogSegments
{
    if (!_trackLogSegments) {
        _trackLogSegments = [NSMutableArray new];
    }
    return _trackLogSegments;
}





#pragma mark - TrackLog Methods - private

- (MissionProperty *)createMissionProperty
{
    MissionProperty * template = [self lastTrackLogSegment].missionProperty;
    MissionProperty *missionProperty = nil;
    GpsPoint *gpsPoint = [self addGpsPointAtLocation:[self.locationDelegate locationOfGPS]];
    if (gpsPoint) {
        missionProperty = [self createMissionPropertyAtGpsPoint:gpsPoint];
    } else {
        missionProperty = [self createMissionPropertyAtMapLocation:[self.locationDelegate locationOfTarget]];
    }
    [self copyAttributesForFeature:self.protocol.missionFeature fromEntity:template toEntity:missionProperty];
    [self drawMissionProperty:missionProperty];
    return missionProperty;
}

- (MissionProperty *)createMissionPropertyAtGpsPoint:(GpsPoint *)gpsPoint
{
    //AKRLog(@"Creating MissionProperty at GPS point");
    if (!gpsPoint.timestamp) {
        AKRLog(@"Unable to create a mission property; timestamp for gps point is nil");
        return nil;
    }
    MissionProperty *missionProperty = [self createSimpleMissionProperty];
    missionProperty.gpsPoint = gpsPoint;
    return missionProperty;
}

- (MissionProperty *)createMissionPropertyAtMapLocation:(AGSPoint *)mapPoint
{
    //AKRLog(@"Creating MissionProperty at Map point");
    AdhocLocation *adhocLocation = [self createAdhocLocationWithMapPoint:mapPoint];
    if (!adhocLocation.timestamp) {
        AKRLog(@"Unable to create a mission property; timestamp for adhoc location is nil");
        [self.document.managedObjectContext deleteObject:adhocLocation];
        return nil;
    }
    MissionProperty *missionProperty = [self createSimpleMissionProperty];
    missionProperty.adhocLocation = adhocLocation;
    return missionProperty;
}

- (MissionProperty *)createSimpleMissionProperty
{
    //AKRLog(@"Creating MissionProperty managed object");
    MissionProperty *missionProperty = [NSEntityDescription insertNewObjectForEntityForName:kMissionPropertyEntityName inManagedObjectContext:self.document.managedObjectContext];
    NSAssert(missionProperty, @"%@", @"Could not create a Mission Property in Core Data");
    missionProperty.mission = self.currentMission;
    missionProperty.observing = self.isObserving;
    return missionProperty;
}

- (void) copyAttributesForFeature:(ProtocolFeature *)feature fromEntity:(NSManagedObject *)fromEntity toEntity:(NSManagedObject *)toEntity
{
    for (NSAttributeDescription *attribute in feature.attributes) {
        id value = [fromEntity valueForKey:attribute.name];
        if (value) {
            [toEntity setValue:value forKey:attribute.name];
        }
    }
}



#pragma mark - Observation Methods - private


- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint
{
    Observation *observation = [self createObservation:feature];
    observation.gpsPoint = gpsPoint;
    return observation;
}

- (Observation *)createObservation:(ProtocolFeature *)feature AtMapLocation:(AGSPoint *)mapPoint
{
    Observation *observation = [self createObservation:feature];
    observation.adhocLocation = [self createAdhocLocationWithMapPoint:mapPoint];
    return observation;
}

- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint withAngleDistanceLocation:(LocationAngleDistance *)angleDistance
{
    Observation *observation = [self createObservation:feature atGpsPoint:gpsPoint];
    observation.angleDistanceLocation = [self createAngleDistanceLocationWithAngleDistanceLocation:angleDistance];
    return observation;
}

- (void)updateAdhocLocation:(AdhocLocation *)adhocLocation withMapPoint:(AGSPoint *)mapPoint
{
    //mapPoint is in the map coordinates, convert to WGS84
    AGSPoint *wgs84Point = (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:mapPoint toSpatialReference:[AGSSpatialReference wgs84SpatialReference]];
    adhocLocation.latitude = wgs84Point.y;
    adhocLocation.longitude = wgs84Point.x;
    if (self.lastGpsPoint && [self.lastGpsPoint.timestamp timeIntervalSinceDate: [NSDate date]] < kStaleInterval) {
        adhocLocation.timestamp = self.lastGpsPoint.timestamp;
        //Used for relating the adhoc observation to where the observer was when the observation was made
    } else {
        adhocLocation.timestamp = [NSDate date];
    }
}




#pragma mark - Observation Methods - private

- (Observation *)createObservation:(ProtocolFeature *)feature
{
    //AKRLog(@"Creating Observation managed object");
    NSString *entityName = [NSString stringWithFormat:@"%@%@",kObservationPrefix,feature.name];
    Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                             inManagedObjectContext:self.document.managedObjectContext];
    NSAssert(observation, @"%@", @"Could not create an Observation in Core Data");
    observation.mission = self.currentMission;
    return observation;
}

- (AdhocLocation *)createAdhocLocationWithMapPoint:(AGSPoint *)mapPoint
{
    //AKRLog(@"Adding Adhoc Location to Core Data at Map Point %@", mapPoint);
    AdhocLocation *adhocLocation = [NSEntityDescription insertNewObjectForEntityForName:kAdhocLocationEntityName
                                                                 inManagedObjectContext:self.document.managedObjectContext];
    NSAssert(adhocLocation, @"%@", @"Could not create an AdhocLocation in Core Data");
    [self updateAdhocLocation:adhocLocation withMapPoint:mapPoint];
    adhocLocation.map = self.currentMapEntity;
    return adhocLocation;
}

- (AngleDistanceLocation *)createAngleDistanceLocationWithAngleDistanceLocation:(LocationAngleDistance *)location
{
    //AKRLog(@"Adding Angle = %f, Distance = %f, Course = %f to CoreData", location.absoluteAngle, location.distanceMeters, location.deadAhead);
    AngleDistanceLocation *angleDistance = [NSEntityDescription insertNewObjectForEntityForName:kAngleDistanceLocationEntityName
                                                                         inManagedObjectContext:self.document.managedObjectContext];
    NSAssert(angleDistance, @"%@", @"Could not create an AngleDistanceLocation in Core Data");
    angleDistance.angle = location.absoluteAngle;
    angleDistance.distance = location.distanceMeters;
    angleDistance.direction = location.deadAhead;
    return angleDistance;
}




#pragma mark - Misc Methods

- (void)deleteObject:(NSManagedObject *)object
{
    [self.document.managedObjectContext deleteObject:object];
}

- (void)loadGraphics
{
    AKRLog(@"Loading graphics from coredata");
    AKRLog(@"  Fetching gpsPoints");
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:kTimestampKey ascending:YES]];
    NSError *error = [[NSError alloc] init];
    NSArray *results = [self.document.managedObjectContext executeFetchRequest:request error:&error];
    AKRLog(@"  Drawing %d gpsPoints", results.count);
    if (!results && error.code)
        AKRLog(@"Error Fetching GpsPoint %@",error);
    GpsPoint *previousPoint;
    MissionProperty *activeMissionProperty = nil;
    for (GpsPoint *gpsPoint in results) {
        //draw each individual GPS point
        [self drawGpsPoint:gpsPoint];

        //Keep track of the previous point to draw tracks
        if (!previousPoint) {
            previousPoint = gpsPoint;
            continue;
        }
        if (previousPoint.mission != gpsPoint.mission) {
            previousPoint = gpsPoint;
            continue;
        }
        if (previousPoint.missionProperty) {
            activeMissionProperty = previousPoint.missionProperty;
        }
        [self drawLineFor:activeMissionProperty from:previousPoint to:gpsPoint];

        previousPoint = gpsPoint;
    }

    //Get Observations
    AKRLog(@"  Fetching observations");
    request = [NSFetchRequest fetchRequestWithEntityName:kObservationEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:&error];
    if (!results && error.code)
        AKRLog(@"Error Fetching Observations %@",error);
    AKRLog(@"  Drawing %d observations", results.count);
    for (Observation *observation in results) {
        [self drawObservation:observation];
    }
    //Get MissionProperties
    AKRLog(@"  Fetching mission properties");
    request = [NSFetchRequest fetchRequestWithEntityName:kMissionPropertyEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:&error];
    if (!results && error.code)
        AKRLog(@"Error Fetching Mission Properties %@",error);
    AKRLog(@"  Drawing %d Mission Properties", results.count);
    for (MissionProperty *missionProperty in results) {
        [self drawMissionProperty:missionProperty];
    }

    AKRLog(@"  Done loading graphics");
}




#pragma mark - Private Drawing Methods

- (void)drawGpsPoint:(GpsPoint *)gpsPoint
{
    AGSPoint *mapPoint = [gpsPoint pointOfGpsWithSpatialReference:self.mapViewSpatialReference];
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:nil];
    [[self graphicsLayerForGpsPoints] addGraphic:graphic];
}

- (void)drawObservation:(Observation *)observation
{
    //AKRLog(@"    Drawing observation type %@",observation.entity.name);
    NSDate *timestamp = [observation timestamp];
    NSAssert(timestamp, @"An observation in %@ has no timestamp", observation.entity.name);
    AGSPoint *mapPoint = [observation pointOfFeatureWithSpatialReference:self.mapViewSpatialReference];
    NSDictionary *attribs = timestamp ? @{kTimestampKey:timestamp} : @{kTimestampKey:[NSNull null]};
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attribs];
    [[self graphicsLayerForObservation:observation] addGraphic:graphic];
}

- (void)drawMissionProperty:(MissionProperty *)missionProperty
{
    NSDate *timestamp = [missionProperty timestamp];
    NSAssert(timestamp, @"A mission property has no timestamp");
    NSDictionary *attribs = timestamp ? @{kTimestampKey:timestamp} : @{kTimestampKey:[NSNull null]};
    AGSPoint *mapPoint = [missionProperty pointOfMissionPropertyWithSpatialReference:self.mapViewSpatialReference];
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attribs];
    [[self graphicsLayerForMissionProperties] addGraphic:graphic];
}

- (void)drawLineFor:(MissionProperty *)mp from:(GpsPoint *)oldPoint to:(GpsPoint *)newPoint
{
    AGSPoint *point1 = [oldPoint pointOfGpsWithSpatialReference:self.mapViewSpatialReference];
    AGSPoint *point2 = [newPoint pointOfGpsWithSpatialReference:self.mapViewSpatialReference];
    AGSMutablePolyline *line = [[AGSMutablePolyline alloc] init];
    [line addPathToPolyline];
    [line addPointToPath:point1];
    [line addPointToPath:point2];
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:line symbol:nil attributes:nil];
    [[self graphicsLayerForTracksLogObserving:mp.observing] addGraphic:graphic];
}

/*
- (void)drawTrackLog:(TrackLogSegment *)trackLog
{
    //TODO: implement
}

- (void)drawLastSegmentOfLastTrackLog
{
    //TODO: implement
}
*/

@end
