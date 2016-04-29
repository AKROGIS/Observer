//
//  Survey.h
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ZipKit/ZipKit.h>
#import "AKRTableViewItem.h"
#import "SProtocol.h"
#import "SurveyCoreDataDocument.h"
#import "ObserverModel.h"
#import "MissionTotalizer.h"

#define INTERNAL_SURVEY_EXT @"obssurv"
#define SURVEY_EXT @"poz"

typedef NS_ENUM(NSUInteger, SurveyState) {
    kUnborn   = 0,
    kCorrupt  = 1,
    kCreated  = 2,
    kModified = 3,
    kSaved    = 4
};

@protocol SurveyLocationDelegate <NSObject>

- (CLLocation *)locationOfGPS;

@end

//This line should not be required (for some unknown reason this file and only this file
//refuses to acknowledge the class definition in the included MissionTotalizer.h file.)
//It is included to keep the compiler for complaining about the definition of the totalizer property
@class MissionTotalizer;

@interface Survey : NSObject <AKRTableViewItem>

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, readonly) SurveyState state;
@property (nonatomic, strong, readonly) NSString *subtitle;
@property (nonatomic, strong, readonly) NSString *statusMessage;

//title and date will block (reading values from the filessytem) if the state is unborn.
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong, readonly) NSDate *date;   //Date of last change (create/edit)
@property (nonatomic, strong, readonly) NSDate *syncDate;

//The following methods will block (reading data from the filessytem)
@property (nonatomic, strong, readonly) UIImage *thumbnail;
@property (nonatomic, strong, readonly) SProtocol *protocol;

//document will return nil until openDocumentWithCompletionHandler is called with success
@property (nonatomic, strong, readonly) UIManagedDocument *document;

// Totalizes the time/distance observing on a mission
@property (nonatomic, strong, readonly) MissionTotalizer *totalizer;

//Initializers
// NOTE: The Designated Initializer is not public, THIS CLASS CANNOT BE SUB-CLASSED
- (id)init __attribute__((unavailable("Must use initWithProtocol: or initWithURL: instead.")));
- (id)initWithURL:(NSURL *)url;
//This involve doing IO (to find and create the unused url), it should be called on a background thread
- (id)initWithProtocol:(SProtocol *)protocol;
- (id)initWithArchive:(NSURL *)archive;

//YES if two Surveys are the same (same url)
- (BOOL)isEqualToSurvey:(Survey *)survey;

//YES if the survey is valid
- (BOOL)isValid;

//YES if the core data context is loaded and normal
- (BOOL)isReady;

//other actions
- (void)openDocumentWithCompletionHandler:(void (^)(BOOL success))handler;
// saving is only for "SaveTO", normal saves are handled by UIKit with autosave
// doing saves as overwrites can work if you get lucky, but may cause conflicts
// I am not supporting saveTo
- (void)closeDocumentWithCompletionHandler:(void (^)(BOOL success))completionHandler;
- (void)syncWithCompletionHandler:(void (^)(NSError*))handler;
- (void)addCSVtoArchive:(ZKDataArchive *)archive since:(NSDate *)startDate;

+ (NSURL *)privateDocumentsDirectory;

// Info for details view
- (NSUInteger)observationCount;
- (NSUInteger)segmentCount;
- (NSUInteger)gpsCount;
- (NSUInteger)gpsCountSinceSync;
- (NSDate *)firstGpsDate;
- (NSDate *)lastGpsDate;



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
- (BOOL)startRecording;
@property (nonatomic, readonly) BOOL isRecording;
- (void)stopRecording;

- (void)setMap:(Map *)map;
- (void)clearMap;

@property (nonatomic, weak) id<SurveyLocationDelegate>locationDelegate;

@property (nonatomic, strong) AGSSpatialReference *mapViewSpatialReference;
- (void)clearMapMapViewSpatialReference;

// GPS Methods
- (GpsPoint *)addGpsPointAtLocation:(CLLocation *)location;

//TrackLogs
- (TrackLogSegment *)startObserving;
@property (nonatomic, readonly) BOOL isObserving;
- (void)stopObserving;
- (TrackLogSegment *)startNewTrackLogSegment;
- (NSArray *) trackLogSegmentsSince:(NSDate *)timestamp;

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
