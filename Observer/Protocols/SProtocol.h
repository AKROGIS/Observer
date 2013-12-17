//
//  SProtocol.h
//  Observer
//
//  Created by Regan Sarwas on 11/18/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AKRTableViewItem.h"
#import "Enumerations.h"

@interface SProtocol : NSObject <NSCoding, AKRTableViewItem>

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSNumber *version;
@property (nonatomic, strong, readonly) NSString *versionString;
@property (nonatomic, strong, readonly) NSDate *date;
@property (nonatomic, strong, readonly) NSString *dateString;
@property (nonatomic, strong, readonly) NSString *details;

//@property (nonatomic, strong, readonly) NSString *date;
@property (nonatomic, strong, readonly) NSDictionary *values;

// features is guaranteed to contain 0 or more NSDictionary with at least the following
// key:@"name" value:NSString
// key:@"attributes" value:NSArray (types in array are not guaranteed)
@property (nonatomic, strong, readonly) NSArray *features;

@property (nonatomic, strong, readonly) NSDictionary *dialogs;

//YES if the protocol is available locally, NO otherwise;
- (BOOL)isLocal;

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


//Does the protocol define the units of measure for angle/distance observations
@property (nonatomic, readonly) BOOL definesAngleDistanceMeasures;

// Does the protocol require that all observations are angle distance
@property (nonatomic, readonly) BOOL requireAngleDistance;

// The units of measure (meters, feet, etc) for distances to observed items
@property (nonatomic, readonly) AGSSRUnit distanceUnits;

// The angle in degrees for dead ahead or true north
@property (nonatomic, readonly) double angleBaseline;

// What is the direction of increasing angles (clockwise or counter-clockwise)
@property (nonatomic, readonly) AngleDirection angleDirection;


@end
