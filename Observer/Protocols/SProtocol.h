//
//  SProtocol.h
//  Observer
//
//  Created by Regan Sarwas on 11/18/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AKRTableViewItem.h"
#import "ProtocolFeature.h"
#import "ProtocolMissionFeature.h"

#define PROTOCOL_EXT @"obsprot"

@interface SProtocol : NSObject <NSCoding, AKRTableViewItem, NSURLSessionDownloadDelegate>

@property (nonatomic, readonly) NSInteger metaversion;
@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSNumber *version;
@property (nonatomic, strong, readonly) NSString *versionString;
@property (nonatomic, strong, readonly) NSDate *date;
@property (nonatomic, strong, readonly) NSString *dateString;
@property (nonatomic, strong, readonly) NSString *details;
@property (nonatomic, strong, readonly) NSString *observingMessage;
@property (nonatomic, strong, readonly) NSString *notObservingMessage;
@property (nonatomic, strong, readonly) NSDictionary *totalizerConfig;
@property (nonatomic, strong, readonly) NSArray *features;  // of ProtocolFeatures
@property (nonatomic, strong, readonly) NSArray *featuresWithLocateByTouch;  // of ProtocolFeatures
@property (nonatomic, strong, readonly) ProtocolMissionFeature *missionFeature;
@property (nonatomic, readonly) BOOL cancelOnTop;
@property (nonatomic, readonly) NSTimeInterval gpsInterval;


// Find a feature's definition
- (ProtocolFeature *)featureWithName:(NSString *)name;

//YES if the protocol is available locally, NO otherwise;
@property (nonatomic, getter=isLocal, readonly) BOOL local;

//YES if the protocol is valid
// currently defined by being able to load/parse the data at url, and find a missionFeature,
// and at least one valid feature in the data.
@property (nonatomic, getter=isValid, readonly) BOOL valid;

//YES if two protocols are the same (same title, version and date)
//    do not compare urls, because the same protocol will have either a local, or a server url
- (BOOL)isEqualToProtocol:(SProtocol *)protocol;

//designated initializer
- (instancetype)initWithURL:(NSURL *)url title:(id)title version:(id)version date:(id)date NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithURL:(NSURL *)url;
- (instancetype) init __attribute__((unavailable("Must use initWithURL: instead.")));

// Save the Protocol to the URL;  This is synchronous, so remote protocols will block
// url must be a file URL
- (BOOL)saveCopyToURL:(NSURL *)url;

// download the Protocol from the remote URL to a local file...
- (void)startDownload;
- (void)cancelDownload;
@property (nonatomic, getter=isDownloading, readonly) BOOL downloading;

// The download should continue if the app is put in the background
@property (nonatomic) BOOL isBackground;
// Where the downloaded file should be stored, must be a file URL
//  if nil, then a unique URL in the Documents folder based on the source URL will be used)
@property (nonatomic, strong) NSURL *destinationURL;
// The download can over-write any existing file at destinationURL
@property (nonatomic) BOOL canReplace;
// A block to execute when there is progress to report
@property (nonatomic, copy) void(^downloadProgressAction)(double bytesWritten, double bytesExpected);
// A block to execute when the file as been stored at 
@property (nonatomic, copy) void(^downloadCompletionAction)(SProtocol *newProtocol);
// The percent complete of the download, saved incase the the popover is dismissed, and then re-presented
@property (nonatomic) double downloadPercentComplete;

// Settings to determine when to show the Mission Properties Attribute Editor
@property (nonatomic) BOOL editMissionPropertiesAtStartRecording;
@property (nonatomic) BOOL editMissionPropertiesAtStartFirstObserving;
@property (nonatomic) BOOL editMissionPropertiesAtStartReObserving;
@property (nonatomic) BOOL editPriorMissionPropertiesAtStopObserving;
@property (nonatomic) BOOL editMissionPropertiesAtStopObserving;

@end
