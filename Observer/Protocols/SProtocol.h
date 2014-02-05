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

@interface SProtocol : NSObject <NSCoding, AKRTableViewItem>

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSNumber *version;
@property (nonatomic, strong, readonly) NSString *versionString;
@property (nonatomic, strong, readonly) NSDate *date;
@property (nonatomic, strong, readonly) NSString *dateString;
@property (nonatomic, strong, readonly) NSString *details;
@property (nonatomic, strong, readonly) NSArray *features;  // of ProtocolFeatures
@property (nonatomic, strong, readonly) NSArray *featuresWithLocateByTouch;  // of ProtocolFeatures
@property (nonatomic, strong, readonly) ProtocolMissionFeature *missionFeature;
@property (nonatomic,         readonly) BOOL allowsAdhocTouchLocations;

//YES if the protocol is available locally, NO otherwise;
- (BOOL)isLocal;

//YES if the protocol is valid
// currently defined by being able to load the data at url, and find at least one valid property
- (BOOL)isValid;

//YES if two protocols are the same (same title, version and date)
//    do not compare urls, because the same protocol will have either a local, or a server url
- (BOOL)isEqualtoProtocol:(Protocol *)protocol;

//designated initializer
- (id)initWithURL:(NSURL *)url title:(id)title version:(id)version date:(id)date;
- (id)initWithURL:(NSURL *)url;
- (id) init __attribute__((unavailable("Must use initWithURL: instead.")));

// download the protocol from the remote URL to a local file...
- (void)prepareToDownload;
- (BOOL)isDownloading;
- (BOOL)downloadToURL:(NSURL *)url;
- (BOOL)saveCopyToURL:(NSURL *)url;


@end
