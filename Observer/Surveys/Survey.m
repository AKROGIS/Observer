//
//  Survey.m
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "Survey.h"
#import "NSURL+unique.h"
#import "NSDate+Formatting.h"
#import "ObserverModel.h"

#define kCodingVersion    1
#define kCodingVersionKey @"codingversion"
#define kUrlKey           @"url"
#define kSTitleKey        @"title"
#define kStateKey         @"state"
#define kDateKey          @"date"

#define kPropertiesFilename @"properties.plist"
#define kProtocolFilename   @"protocol.obsprot"
#define kThumbnailFilename  @"thumbnail.png"
#define kDocumentFilename   @"survey.coredata"

@interface Survey () {
    //private ivars for the mapping related interface
    NSMutableDictionary *_graphicsLayersByName;
}

@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, readwrite) SurveyState state;
@property (nonatomic, strong, readwrite) NSDate *date;
@property (nonatomic, strong, readwrite) UIImage *thumbnail;
@property (nonatomic, strong, readwrite) SProtocol *protocol;
@property (nonatomic, strong, readwrite) UIManagedDocument *document;
@property (nonatomic, strong) NSURL *propertiesUrl;
@property (nonatomic, strong) NSURL *thumbnailUrl;
@property (nonatomic, strong) NSURL *protocolUrl;
@property (nonatomic, strong) NSURL *documentUrl;
@property (nonatomic) BOOL protocolIsLoaded;
@property (nonatomic) BOOL thumbnailIsLoaded;
@property (nonatomic) BOOL documentIsLoaded;

//private properties for the mapping related interface
@property (nonatomic, strong) MapReference *currentMapEntity;
@property (nonatomic, strong, readwrite) Mission *currentMission;
@property (nonatomic, strong, readwrite) GpsPoint *lastGpsPoint;
@property (nonatomic, strong) NSMutableArray * trackLogSegments;
@property (nonatomic, strong) MissionProperty *lastAdHocMissionProperty;
@property (nonatomic, readwrite) BOOL isObserving;
@property (nonatomic, readwrite) BOOL isRecording;

@end

@implementation Survey

#pragma mark - initializers

- (id)initWithURL:(NSURL *)url title:(NSString *)title state:(SurveyState)state date:(NSDate *)date
{
    if (!url) {
        return nil;
    }
    if (self = [super init]) {
        _url = url;
        _state = state;
        _date = date;
        _title = title;
        _protocolIsLoaded = NO;
        _thumbnailIsLoaded = NO;
    }
    return self;
}

- (id)initWithURL:(NSURL *)url
{
    return [self initWithURL:url title:nil state:kUnborn date:[NSDate date]];
}

- (id)initWithProtocol:(SProtocol *)protocol
{
    //verify the input - reading protocol values may cause protocol to load from filesystem
    if (!protocol.isValid) {
        return nil;
    }
    //find a suitable URL (reads filesystem)
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSString *filename = [NSString stringWithFormat:@"%@.%@", protocol.title, SURVEY_EXT];
    //the trailing slash is added because it is a directory, and this standardizes the URL for comparisons
    NSURL *url = [[[documentsDirectory URLByAppendingPathComponent:filename] URLByUniquingPath] URLByAppendingPathComponent:@"/"];
    NSString *title = [[url lastPathComponent] stringByDeletingPathExtension];
    self = [self initWithURL:url title:title state:kCreated date:[NSDate date]];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:nil]) {
        return nil;
    };
    if (![protocol saveCopyToURL:self.protocolUrl]) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        return nil;
    }
    [self saveProperties];
    return self;
}


#pragma mark property accessors

@synthesize title = _title;

- (NSString *)title
{
    if (self.state == kUnborn) {
        [self loadProperties];
    }
    return _title;
}

- (void)setTitle:(NSString *)title
{
    if (_title != title) {
        _title = title;
        [self saveProperties];
        //TODO: we should also rename the URL, to simiplify recognition in transfers
    }
}

- (NSDate *)date
{
    if (self.state == kUnborn) {
        [self loadProperties];
    }
    return _date;
}

- (NSString *)subtitle
{
    return [NSString stringWithFormat:@"Protocol: %@, v. %@",self.protocol.title, self.protocol.version];
}

- (NSString *)subtitle2
{
    NSString *status = nil;
    switch (self.state) {
        case kUnborn:
            status = @"Unborn";
            break;
        case kCorrupt:
            status = @"Corrupt";
            break;
        case kCreated:
            status = @"Created";
            break;
        case kModified:
            status = @"Modified";
            break;
        case kSaved:
            status = @"Saved";
            break;
        default:
            status = @"Unknown State";
            break;
    }
    return [NSString stringWithFormat:@"%@: %@",status, [self.date stringWithMediumDateTimeFormat]];
}

- (UIImage *)thumbnail
{
    if (!_thumbnail && !self.thumbnailIsLoaded) {
        [self loadThumbnail];
    }
    return _thumbnail;
}

- (SProtocol *)protocol
{
    if (!_protocol && !self.protocolIsLoaded) {
        [self loadProtocol];
    }
    return _protocol;
}

- (NSURL *)propertiesUrl
{
    if (!_propertiesUrl) {
        _propertiesUrl = [self.url URLByAppendingPathComponent:kPropertiesFilename];
    }
    return _propertiesUrl;
}

- (NSURL *)thumbnailUrl
{
    if (!_thumbnailUrl) {
        _thumbnailUrl = [self.url URLByAppendingPathComponent:kThumbnailFilename];
    }
    return _thumbnailUrl;
}

- (NSURL *)protocolUrl
{
    if (!_protocolUrl) {
        _protocolUrl = [self.url URLByAppendingPathComponent:kProtocolFilename];
    }
    return _protocolUrl;
}

- (NSURL *)documentUrl
{
    if (!_documentUrl) {
        _documentUrl = [self.url URLByAppendingPathComponent:kDocumentFilename];
    }
    return _documentUrl;
}

#pragma mark - public methods

- (BOOL)isEqualToSurvey:(Survey *)survey
{
    //Comparing URLs is tricky, I am trying to be efficient, and permissive
    return ([self.url isEqual:survey.url] ||
            [self.url.absoluteURL isEqual:survey.url.absoluteURL] ||
            [self.url.fileReferenceURL isEqual:survey.url.fileReferenceURL]);
}

- (BOOL) isValid
{
    //TODO: improve this method
    return self.protocol != nil;
}

- (BOOL)isReady
{
    return self.document.managedObjectContext != nil && self.document.documentState == UIDocumentStateNormal;
}

//TODO: figure out error handling.
//TODO: this public method isn't used - justify the API or remove
- (void)readPropertiesWithCompletionHandler:(void (^)(NSError*))handler
{
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer",DISPATCH_QUEUE_CONCURRENT), ^{
        if (![self loadProperties]) {
            self.state = kCorrupt;
        }
        [self loadProtocol];
        [self loadThumbnail];
        NSError *error;
        if (self.state == kCorrupt) {
            NSMutableDictionary* errorDetails = [NSMutableDictionary dictionary];
            [errorDetails setValue:@"Survey File is corrupt" forKey:NSLocalizedDescriptionKey];
            // populate the error object with the details
            error = [NSError errorWithDomain:@"gov.nps.akr.observer" code:1 userInfo:errorDetails];
        }
        if (handler) handler(error);
    });
}

- (void)openDocumentWithCompletionHandler:(void (^)(BOOL success))handler
{
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer",DISPATCH_QUEUE_CONCURRENT), ^{
        //during development, it is possible that a previously valid protocol is no longer recognized as valid
        //we might be able to remove this check in production code.
        if (!self.protocol.isValid) {
            self.state = kCorrupt;
        }
        if (self.state == kCorrupt) {
            if (handler) handler(NO);
        } else {
            self.document = [[SurveyCoreDataDocument alloc] initWithFileURL:self.documentUrl];
            BOOL documentExists = [[NSFileManager defaultManager] fileExistsAtPath:[self.documentUrl path]];
            if (documentExists) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.document openWithCompletionHandler:handler];  //fails unless executed on UI thread
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.document saveToURL:self.documentUrl forSaveOperation:UIDocumentSaveForCreating completionHandler:handler];
                });
            }
        }
    });
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(objectsDidChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:self.document.managedObjectContext];
#ifdef DEBUG
    [self connectToNotificationCenter];
#endif
}

- (void)closeDocumentWithCompletionHandler:(void (^)(BOOL success))completionHandler
{
#ifdef DEBUG
    AKRLog(@"Closing document");
    [self logStats];
    [self disconnectFromNotificationCenter];
#endif
    [self.document closeWithCompletionHandler:completionHandler];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)syncWithCompletionHandler:(void (^)(NSError*))handler
{
    //TODO: Implement
    self.date = [NSDate date];
    self.state = kSaved;
}


#pragma mark - private methods

- (BOOL)loadProperties
{
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfURL:self.propertiesUrl];
    NSInteger version = [plist[kCodingVersionKey] integerValue];
    switch (version) {
        case 1:
            _title = plist[kSTitleKey];
            _state = [plist[kStateKey] unsignedIntegerValue];
            _date = plist[kDateKey];
            return YES;
        default:
            return NO;
    }
}

- (BOOL)loadProtocol
{
    self.protocolIsLoaded = YES;
    _protocol = [[SProtocol alloc] initWithURL:self.protocolUrl];
    //TODO: can we delay the validity check which loads and parses the protocol file
    if (!_protocol.isValid) {
        self.state = kCorrupt;
        _protocol = nil;
        return NO;
    }
    return YES;
}

- (BOOL)loadThumbnail
{
    self.thumbnailIsLoaded = YES;
    _thumbnail = [[UIImage alloc] initWithContentsOfFile:[self.thumbnailUrl path]];
    if (!_thumbnail)
        _thumbnail = [UIImage imageNamed:@"SurveyDoc"];
    return !_thumbnail;
}


- (void)documentChanged:(id)sender {
    self.state = kModified;
    self.date = [NSDate date];
    [self saveProperties];
    //TODO: build new thumbnail and save;
}

- (BOOL)saveProperties {
    //TODO: omit null values from the dictionary, and then check for missing keys on load
    if (!self.title || !self.date) {
        return NO;
    }
    NSDictionary *plist = @{kCodingVersionKey:@kCodingVersion,
                            kSTitleKey:self.title,
                            kStateKey:@(self.state),
                            kDateKey:self.date};
    return [plist writeToURL:self.propertiesUrl atomically:YES];
}

- (BOOL)saveThumbnail
{
    return [UIImagePNGRepresentation(self.thumbnail) writeToFile:[self.thumbnailUrl path] atomically:YES];
}


- (void)objectsDidChange:(NSNotification *)notification
{
#ifdef DEBUG
    AKRLog(@"Survey.document.managedObjectContext objects did change.");
#endif
    self.date = [NSDate date];
    self.state = kModified;
    //do not save properties (write a file to disk) here, since this is called a lot - do it when coredata saves
}

- (NSString *)description
{
    if (self.state == kUnborn) {
        return @"Unborn survey (properties not yet loaded from disk)";
    } else {
        return [NSString stringWithFormat:@"%@; %@; %@", self.title, self.subtitle2, self.protocolIsLoaded ? self.subtitle : @"protocol not yet loaded"];
    }
}




#pragma mark - MAPPING RELATED ROUTINES

#pragma mark - Layer Methods

- (NSDictionary *)graphicsLayersByName
{
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

- (BOOL)startRecording
{
    if (self.isRecording) {
        return YES;
    }
    if(!self.isReady) {
        return NO;
    }
    self.currentMission = [NSEntityDescription insertNewObjectForEntityForName:kMissionEntityName
                                                        inManagedObjectContext:self.document.managedObjectContext];
    NSAssert(self.currentMission, @"Could not create a Mission in Core Data Context %@", self.document.managedObjectContext);
    if (!self.currentMission) {
        return NO;
    }
    TrackLogSegment *newTrackLogSegment = [self startNewTrackLogSegment];
    if (!newTrackLogSegment) {
        return NO;
    }
    self.isRecording = YES;
    return YES;
}

- (void)stopRecording
{
    self.isObserving = NO;
    self.lastGpsPoint = nil;
    self.currentMission = nil;
    self.isRecording = NO;
}

- (void)setMap:(Map *)map
{
    // try to fetch it, otherwise create it.
    //AKRLog(@"Looking for %@ in coredata",map);
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kMapEntityName];

    request.predicate = [NSPredicate predicateWithFormat:@"name == %@ AND author == %@ AND date == %@",
                         map.title, map.author, map.date];
    NSArray *results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    self.currentMapEntity = [results firstObject];
    if(!self.currentMapEntity) {
        //AKRLog(@"  Map not found, creating new CoreData Entity");
        self.currentMapEntity = [NSEntityDescription insertNewObjectForEntityForName:kMapEntityName inManagedObjectContext:self.document.managedObjectContext];
        NSAssert(self.currentMapEntity, @"Could not create a Map Reference in Core Data Context %@", self.document.managedObjectContext);
        self.currentMapEntity.name = map.title;
        self.currentMapEntity.author = map.author;
        self.currentMapEntity.date = map.date;
    }
}

- (void)clearMap
{
    self.currentMapEntity = nil;
}

- (void)clearMapMapViewSpatialReference
{
    self.mapViewSpatialReference = nil;
}




#pragma mark - GPS Methods

- (GpsPoint *)addGpsPointAtLocation:(CLLocation *)location
{
    if ([self isNewLocation:location]) {
        GpsPoint *gpsPoint = [self createGpsPoint:location];
        if (gpsPoint) {
            [[self lastTrackLogSegment].gpsPoints addObject:gpsPoint];
            [self drawGpsPoint:gpsPoint];
            if (self.lastGpsPoint) {
                [self drawLineFor:[self lastTrackLogSegment].missionProperty from:self.lastGpsPoint to:gpsPoint];
            }
            self.lastGpsPoint = gpsPoint;
        }
        return gpsPoint;
    } else {
        return self.lastGpsPoint;
    }
}




#pragma mark - GPS Methods - private

- (BOOL)isNewLocation:(CLLocation *)location
{
    if (!self.lastGpsPoint)
        return YES;
#ifdef AKR_DEBUG
    //This is used to reduce the frequency of the 'identical' points recieved on the simulator
    //need to keep this small, or else we may fail when features try to "share" a gps point
    if ([location.timestamp timeIntervalSinceDate:self.lastGpsPoint.timestamp] > 2.0)
        return YES;
    //Using a mean radius of 6371km, each degree at the equator = 111194.9 meters. (pi*D/360).
    //Therefore .00001 deg is 1.195 meters or less (longitude will be less away from the equator)
    if (fabs(location.coordinate.latitude - self.lastGpsPoint.latitude) > 0.00001)
        return YES;
    if (fabs(location.coordinate.longitude - self.lastGpsPoint.longitude) > 0.00001)
        return YES;
#else
    if ([location.timestamp timeIntervalSinceDate:self.lastGpsPoint.timestamp] > 0.0)
        return YES;
#endif
    return NO;
}

- (GpsPoint *)createGpsPoint:(CLLocation *)gpsData
{
    //AKRLog(@"Creating GpsPoint, Lat = %f, lon = %f, timestamp = %@", gpsData.coordinate.latitude, gpsData.coordinate.longitude, gpsData.timestamp);
    NSAssert(gpsData.timestamp, @"Can't save a GPS Point without a timestamp: %@",gpsData);
    if (!gpsData.timestamp) {
        return nil;
    }
    if (self.lastGpsPoint && [self.lastGpsPoint.timestamp timeIntervalSinceDate:gpsData.timestamp] == 0) {
        return self.lastGpsPoint;
    }
    GpsPoint *gpsPoint = [NSEntityDescription insertNewObjectForEntityForName:kGpsPointEntityName
                                                       inManagedObjectContext:self.document.managedObjectContext];
    NSAssert(gpsPoint, @"Could not create a GPS Point in Core Data Context %@", self.document.managedObjectContext);
    if (!gpsPoint) {
        return nil;
    }
    NSAssert(self.currentMission, @"%@", @"There is no current mission - can't create gps point");
    if (!self.currentMission) {
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
    gpsPoint.timestamp = gpsData.timestamp;
    gpsPoint.verticalAccuracy = gpsData.verticalAccuracy;
    return gpsPoint;
}




#pragma mark - TrackLog Methods - private

- (TrackLogSegment *)startObserving
{
    self.isObserving = YES;
    return [self startNewTrackLogSegment];
}

- (void)stopObserving
{
    self.isObserving = NO;
    [self startNewTrackLogSegment];
}

- (TrackLogSegment *)startNewTrackLogSegment
{
    TrackLogSegment *newTrackLog = nil;
    MissionProperty *missionProperty = [self createMissionPropertyForTrackLog];
    if (missionProperty.gpsPoint) {
        if ([self lastTrackLogSegment].missionProperty == missionProperty) {
            //happens if the new mission property has the same gps point as the prior mission property
            newTrackLog = [self lastTrackLogSegment];
        } else {
            newTrackLog = [TrackLogSegment new];
            newTrackLog.missionProperty = missionProperty;
            newTrackLog.gpsPoints = [NSMutableArray arrayWithObject:missionProperty.gpsPoint];
            [self.trackLogSegments addObject:newTrackLog];
        }
    }
    return newTrackLog;
}

- (TrackLogSegment *)lastTrackLogSegment
{
    return [self.trackLogSegments lastObject];
}

/*
 - (NSDictionary *)currentEnvironmentValues
 {
 //TODO: implement or remove
 return nil;
 }

 - (void)updateTrackLogSegment:(TrackLogSegment *)trackLogSegment attributes:(NSDictionary *)attributes
 {
 //TODO: implement or remove
 }

 - (TrackLogSegment *)trackLogSegmentAtTimestamp:(NSDate *)timestamp
 {
 //TODO: implement or remove
 return nil;
 }
 */

- (NSArray *)trackLogSegmentsSince:(NSDate *)timestamp
{
    if (timestamp) {
        return [self.trackLogSegments filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
            TrackLogSegment *tracklog = (TrackLogSegment *)obj;
            NSComparisonResult ordering = [tracklog.missionProperty.gpsPoint.timestamp compare:timestamp];
            return ordering != NSOrderedAscending;
        }]];
    } else {
        return [self.trackLogSegments copy];
    }
}

- (NSMutableArray *)trackLogSegments
{
    if (!_trackLogSegments) {
        _trackLogSegments = [NSMutableArray new];
    }
    return _trackLogSegments;
}




#pragma mark - Non-TrackLogging Mission Property

- (MissionProperty *)createMissionPropertyAtMapLocation:(AGSPoint *)mapPoint
{
    MissionProperty *template = self.lastAdHocMissionProperty;
    MissionProperty *missionProperty = [self privateCreateMissionPropertyAtMapLocation:mapPoint];
    [self copyAttributesForFeature:self.protocol.missionFeature fromEntity:template toEntity:missionProperty];
    [self drawMissionProperty:missionProperty];
    if (missionProperty) {
        self.lastAdHocMissionProperty = missionProperty;
    }
    return missionProperty;
}




#pragma mark - TrackLog Methods - private

- (MissionProperty *)createMissionPropertyForTrackLog
{
    MissionProperty *missionProperty = nil;
    GpsPoint *gpsPoint = [self addGpsPointAtLocation:[self.locationDelegate locationOfGPS]];
    if (gpsPoint.timestamp) {
        missionProperty = [self createMissionPropertyAtGpsPoint:gpsPoint];
        MissionProperty *template = [self lastTrackLogSegment].missionProperty;
        [self copyAttributesForFeature:self.protocol.missionFeature fromEntity:template toEntity:missionProperty];
        [self drawMissionProperty:missionProperty];
        if (template && (!template.gpsPoint || template.gpsPoint == gpsPoint)) {
            //The prior mission property had it's gps point "stolen" by the new mission property (there is a one-to-one relationship)
            //so replace the prior mission property is replaced by the new mission property
            [self.document.managedObjectContext deleteObject:template];
            [self lastTrackLogSegment].missionProperty = missionProperty;
        }
    }
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

- (MissionProperty *)privateCreateMissionPropertyAtMapLocation:(AGSPoint *)mapPoint
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
    missionProperty.observing = YES;
    return missionProperty;
}

- (MissionProperty *)createSimpleMissionProperty
{
    //AKRLog(@"Creating MissionProperty managed object");
    MissionProperty *missionProperty = [NSEntityDescription insertNewObjectForEntityForName:kMissionPropertyEntityName inManagedObjectContext:self.document.managedObjectContext];
    NSAssert(missionProperty, @"Could not create a Mission Property in Core Data Context %@", self.document.managedObjectContext);
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
    NSAssert(observation, @"Could not create an Observation in Core Data Context %@", self.document.managedObjectContext);
    observation.mission = self.currentMission;
    return observation;
}

- (AdhocLocation *)createAdhocLocationWithMapPoint:(AGSPoint *)mapPoint
{
    //AKRLog(@"Adding Adhoc Location to Core Data at Map Point %@", mapPoint);
    AdhocLocation *adhocLocation = [NSEntityDescription insertNewObjectForEntityForName:kAdhocLocationEntityName
                                                                 inManagedObjectContext:self.document.managedObjectContext];
    NSAssert(adhocLocation, @"Could not create an AdhocLocation in Core Data Context %@", self.document.managedObjectContext);
    [self updateAdhocLocation:adhocLocation withMapPoint:mapPoint];
    adhocLocation.map = self.currentMapEntity;
    return adhocLocation;
}

- (AngleDistanceLocation *)createAngleDistanceLocationWithAngleDistanceLocation:(LocationAngleDistance *)location
{
    //AKRLog(@"Adding Angle = %f, Distance = %f, Course = %f to CoreData", location.absoluteAngle, location.distanceMeters, location.deadAhead);
    AngleDistanceLocation *angleDistance = [NSEntityDescription insertNewObjectForEntityForName:kAngleDistanceLocationEntityName
                                                                         inManagedObjectContext:self.document.managedObjectContext];
    NSAssert(angleDistance, @"Could not create an AngleDistanceLocation in Core Data Context %@", self.document.managedObjectContext);
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
    if (!results && error.code) {
        AKRLog(@"  Error Fetching GpsPoint %@",error);
    } else {
        AKRLog(@"  Drawing %d gpsPoints", results.count);
        Mission *mission = nil;

        self.trackLogSegments = nil;  //make sure we clear our tracklogs (maybe we are reloading)

        for (GpsPoint *gpsPoint in results) {

            //draw each individual GPS point
            //[self drawGpsPoint:gpsPoint];

            //Create the tracklogs from the gps points
            //  A tracklog is an ordered sequence of gpsPoints, and some properties (i.e. the mission properties)
            //  A track log starts at a gpsPoint with a related mission property
            //  The first point of a tracklog might also be the last point of the prior track log (if the mission is the same)
            if (gpsPoint.missionProperty) {
                if (mission == gpsPoint.mission) {
                    [[self lastTrackLogSegment].gpsPoints addObject:gpsPoint];
                }
                mission = gpsPoint.mission;
                TrackLogSegment *newTrackLog = [TrackLogSegment new];
                newTrackLog.missionProperty = gpsPoint.missionProperty;
                newTrackLog.gpsPoints = [NSMutableArray new];
                [self.trackLogSegments addObject:newTrackLog];
            }
            [[self lastTrackLogSegment].gpsPoints addObject:gpsPoint];
        }
        for (TrackLogSegment *tracklog in self.trackLogSegments) {
            [self drawTrackLogSegment:tracklog];
        }
    }
    //Get Observations
    AKRLog(@"  Fetching observations");
    request = [NSFetchRequest fetchRequestWithEntityName:kObservationEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:&error];
    if (!results && error.code) {
        AKRLog(@"  Error Fetching Observations %@",error);
    } else {
        AKRLog(@"  Drawing %d observations", results.count);
        for (Observation *observation in results) {
            [self drawObservation:observation];
        }
    }

    //Get MissionProperties
    AKRLog(@"  Fetching mission properties");
    request = [NSFetchRequest fetchRequestWithEntityName:kMissionPropertyEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:&error];
    if (!results && error.code) {
        AKRLog(@"  Error Fetching Mission Properties %@",error);
    } else {
        AKRLog(@"  Drawing %d Mission Properties", results.count);
        for (MissionProperty *missionProperty in results) {
            [self drawMissionProperty:missionProperty];
        }
    }

    AKRLog(@"  Done loading graphics");
}




#pragma mark - Private Drawing Methods

- (void)drawGpsPoint:(GpsPoint *)gpsPoint
{
    NSAssert(gpsPoint.timestamp, @"An gpsPoint has no timestamp: %@", gpsPoint);
    if (!gpsPoint.timestamp) return; //AKRLog(@"##ERROR## - A gpsPoint has no timestamp %@",gpsPoint);
    AGSPoint *mapPoint = [gpsPoint pointOfGpsWithSpatialReference:self.mapViewSpatialReference];
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:nil];
    [[self graphicsLayerForGpsPoints] addGraphic:graphic];
}

- (void)drawObservation:(Observation *)observation
{
    //AKRLog(@"    Drawing observation type %@",observation.entity.name);
    NSDate *timestamp = [observation timestamp];
    NSAssert(timestamp, @"An observation has no timestamp: %@", observation);
    if (!timestamp) return; //AKRLog(@"##ERROR## - A observation has no timestamp %@",observation);
    AGSPoint *mapPoint = [observation pointOfFeatureWithSpatialReference:self.mapViewSpatialReference];
    NSDictionary *attribs = timestamp ? @{kTimestampKey:timestamp} : @{kTimestampKey:[NSNull null]};
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attribs];
    [[self graphicsLayerForObservation:observation] addGraphic:graphic];
}

- (void)drawMissionProperty:(MissionProperty *)missionProperty
{
    NSDate *timestamp = [missionProperty timestamp];
    NSAssert(timestamp, @"A mission property has no timestamp: %@",missionProperty);
    if (!timestamp) {
        AKRLog(@"##ERROR## - A mission property has no timestamp: %@",missionProperty);
        return;
    }
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


- (void)drawTrackLogSegment:(TrackLogSegment *)tracklog
{
    AGSMutablePolyline *pline = [[AGSMutablePolyline alloc] init];
    [pline addPathToPolyline];
    for (GpsPoint *gpsPoint in tracklog.gpsPoints) {
        [pline addPointToPath:[gpsPoint pointOfGpsWithSpatialReference:self.mapViewSpatialReference]];
    }
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:pline symbol:nil attributes:nil];
    [[self graphicsLayerForTracksLogObserving:tracklog.missionProperty.observing] addGraphic:graphic];
}

/*
 - (void)drawLastSegmentOfLastTrackLog
 {
 //TODO: implement or remove
 }
 */




#pragma mark - Diagnostic aids - remove when done -

#ifdef DEBUG

- (void) connectToNotificationCenter
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(documentStateChanged:)
                                                 name:UIDocumentStateChangedNotification
                                               object:self.document];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dataChanged:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:self.document.managedObjectContext];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dataSaved:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:self.document.managedObjectContext];
}

- (void) disconnectFromNotificationCenter
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDocumentStateChangedNotification
                                                  object:self.document];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextObjectsDidChangeNotification
                                                  object:self.document.managedObjectContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:self.document.managedObjectContext];
}

- (void) documentStateChanged: (NSNotification *)notification
{
    //name should always be UIDocumentStateChangedNotification
    //object should always be self.document
    //userinfo is nil

    AKRLog(@"Document (%@) state changed", self.title);
    switch (self.document.documentState) {
        case UIDocumentStateNormal:
            AKRLog(@"  Document is normal");
            break;
        case UIDocumentStateClosed:
            AKRLog(@"  Document is closed");
            break;
        case UIDocumentStateEditingDisabled:
            AKRLog(@"  Document editing is disabled");
            break;
        case UIDocumentStateInConflict:
            AKRLog(@"  Document is in conflict");
            break;
        case UIDocumentStateSavingError:
            AKRLog(@"  Document has an error saving state");
            break;
        default:
            AKRLog(@"  Document has an unexpected state: %d",self.document.documentState);
    }
}

- (void) dataChanged: (NSNotification *)notification
{
    //name should always be NSManagedObjectContextObjectsDidChangeNotification
    //object should always be self.document
    //userinfo has keys NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey which all return arrays of objects

    AKRLog(@"Document (%@) data changed", self.title);
    //AKRLog(@"Data Changed; \nname:%@ \nobject:%@ \nuserinfo:%@", notification.name, notification.object, notification.userInfo);
}

- (void) dataSaved: (NSNotification *)notification
{
    //name should always be NSManagedObjectContextDidSaveNotification
    //object should always be self.document
    //userinfo has keys NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey which all return arrays of objects

    AKRLog(@"Document (%@) data saved", self.title);
    //AKRLog(@"Data Saved; \nname:%@ \nobject:%@ \nuserinfo:%@", notification.name, notification.object, notification.userInfo);
    [self saveProperties];
}

- (void)logStats
{
    AKRLog(@"  Survey (%@) contains:", self.title);
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
    NSArray *results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d GpsPoints", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kObservationEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d Observations", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kMissionPropertyEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d MissionProperties", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kMissionEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d Missions", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kMapEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d Maps", results.count);
}

#endif

@end
