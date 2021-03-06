//
//  Survey.h
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ZipKit/ZipKit.h>

#import "AKRTableViewItem.h"
#import "AngleDistanceLocation.h"
#import "LocationAngleDistance.h"
#import "Observation.h"
#import "MissionTotalizer.h"
#import "SProtocol.h"
#import "SurveyCoreDataDocument.h"
#import "TrackLogSegment.h"

#define INTERNAL_SURVEY_EXT @"obssurv"
#define SURVEY_EXT @"poz"

typedef NS_ENUM(NSUInteger, SurveyState) {
    kUnborn   = 0,
    kCorrupt  = 1,
    kCreated  = 2,
    kModified = 3,
    kSaved    = 4
};

//This line should not be required (for some unknown reason this file and only this file
//refuses to acknowledge the class definition in the included MissionTotalizer.h file.)
//It is included to keep the compiler for complaining about the definition of the totalizer property
@class MissionTotalizer;

@interface Survey : NSObject <AKRTableViewItem>

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSString *lastPathComponent;
@property (nonatomic, readonly) SurveyState state;
@property (nonatomic, strong, readonly) NSString *statusMessage;

//title and date will block (reading values from the filessytem) if the state is unborn.
@property (nonatomic, strong, readonly) NSDate *date;   //Date of last change (create/edit)
@property (nonatomic, strong, readonly) NSDate *syncDate;

//The following methods will block (reading data from the filessytem)
@property (nonatomic, strong, readonly) UIImage *thumbnail;
@property (nonatomic, strong, readonly) SProtocol *protocol;

- (void)setTitle:(NSString *)title;

//document will return nil until openDocumentWithCompletionHandler is called with success
@property (nonatomic, strong, readonly) UIManagedDocument *document;

// Totalizes the time/distance observing on a mission
@property (nonatomic, strong, readonly) MissionTotalizer *totalizer;

//Initializers
// NOTE: The Designated Initializer is not public, THIS CLASS CANNOT BE SUB-CLASSED
- (instancetype)init __attribute__((unavailable("Must use initWithProtocol: or initWithURL: instead.")));
- (instancetype)initWithURL:(NSURL *)url;
//This involve doing IO (to find and create the unused url), it should be called on a background thread
- (instancetype)initWithProtocol:(SProtocol *)protocol;
- (instancetype)initWithArchive:(NSURL *)archive;

//YES if two Surveys are the same (same url)
- (BOOL)isEqualToSurvey:(Survey *)survey;

//YES if the survey is valid
@property (nonatomic, getter=isValid, readonly) BOOL valid;

//YES if the core data context is loaded and normal
@property (nonatomic, getter=isReady, readonly) BOOL ready;

//other actions
- (void)openDocumentWithCompletionHandler:(void (^)(BOOL success))handler;
// saving is only for "SaveTO", normal saves are handled by UIKit with autosave
// doing saves as overwrites can work if you get lucky, but may cause conflicts
// I am not supporting saveTo
- (void)closeDocumentWithCompletionHandler:(void (^)(BOOL success))completionHandler;
- (void)syncWithCompletionHandler:(void (^)(NSError*))handler;
- (void)addCSVtoArchive:(ZKDataArchive *)archive since:(NSDate *)startDate;

+ (NSURL *)privateDocumentsDirectory;
+ (NSURL *)urlFromCachedName:(NSString *)name;

// Info for details view
@property (nonatomic, readonly) NSUInteger observationCount;
@property (nonatomic, readonly) NSUInteger segmentCount;
@property (nonatomic, readonly) NSUInteger gpsCount;
@property (nonatomic, readonly) NSUInteger gpsCountSinceSync;
@property (nonatomic, readonly, copy) NSDate *firstGpsDate;
@property (nonatomic, readonly, copy) NSDate *lastGpsDate;



// Mapping Related Interface

// Layer Methods
@property (nonatomic, strong, readonly) NSDictionary *graphicsLayersByName;
- (AGSGraphicsLayer *)graphicsLayerForObservation:(Observation *)observation;
- (AGSGraphicsLayer *)graphicsLayerForFeature:(ProtocolFeature *)feature;

- (BOOL)isSelectableLayerName:(NSString *)layerName;
- (NSManagedObject *)entityOnLayerNamed:(NSString *)layerName atTimestamp:(NSDate *)timestamp;
- (ProtocolFeature *)protocolFeatureFromLayerName:(NSString *)layerName;

//Entity Methods
- (Observation *)observationFromEntity:(NSManagedObject *)entity;
- (MissionProperty *)missionPropertyFromEntity:(NSManagedObject *)entity;
- (AngleDistanceLocation *)angleDistanceLocationFromEntity:(NSManagedObject *)entity;
- (GpsPoint *)gpsPointFromEntity:(NSManagedObject *)entity;
- (AdhocLocation *)adhocLocationFromEntity:(NSManagedObject *)entity;
- (void)deleteEntity:(NSManagedObject *)entity;

// State Control
- (BOOL)startRecording:(CLLocation *)locationOfGPS;
@property (nonatomic, readonly) BOOL isRecording;
- (void)stopRecording:(CLLocation *)locationOfGPS;

- (void)setMap:(Map *)map;

@property (nonatomic, strong) AGSSpatialReference *mapViewSpatialReference;

// GPS Methods
// Location should be checked by caller to ensure it is a good/current location
- (void)maybeAddGpsPointAtLocation:(CLLocation *)location;
- (GpsPoint *)addGpsPointAtLocation:(CLLocation *)location;

//TrackLogs
- (TrackLogSegment *)startObserving:(CLLocation *)locationOfGPS;
@property (nonatomic, readonly) BOOL isObserving;
- (void)stopObserving:(CLLocation *)locationOfGPS;
- (TrackLogSegment *)startNewTrackLogSegment:(CLLocation *)locationOfGPS;
- (NSArray *) trackLogSegmentsSince:(NSDate *)timestamp;
@property (nonatomic, readonly, strong) TrackLogSegment *lastTrackLogSegment;


//Non-TrackLogging Mission Property
- (MissionProperty *)createMissionPropertyAtMapLocation:(AGSPoint *)mapPoint;

// Observations
- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint;
- (Observation *)createObservation:(ProtocolFeature *)feature atMapLocation:(AGSPoint *)mapPoint;
- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint withAngleDistanceLocation:(LocationAngleDistance *)angleDistance;
- (AGSGraphic *)drawObservation:(Observation *)observation;
- (void)updateAdhocLocation:(AdhocLocation *)adhocLocation withMapPoint:(AGSPoint *)mapPoint;
- (void)updateAngleDistanceObservation:(Observation *)observation withAngleDistance:(LocationAngleDistance *)locationAngleDistance;

// Miscellaneous
- (void)loadGraphics;
#ifdef AKR_DEBUG
- (void)logStats;
#endif
@end
