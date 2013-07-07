//
//  Map.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MapMonitoring.h"

typedef enum {
    MapStatusNormal,
    MapStatusDownloading,
    MapStatusDownloadFailed,
    MapStatusLoading,
    MapStatusLoadFailed
} MapStatus;

#define TILE_CACHE_EXTENSION @"tpk"

@interface Map : NSObject

//designated initializer
- (id) initWithLocalURL:(NSURL *)localURL andServerURL:(NSURL *)serverUrl;

- (id) initWithLocalURL:(NSURL *)localURL;
- (id) initWithServerURL:(NSURL *)serverUrl;
- (id) init; // don't call this - it overrides super init to prevent malformed objects

@property (strong, nonatomic, readonly) NSURL *localURL;
@property (strong, nonatomic, readonly) NSURL *serverURL;
@property (nonatomic, readonly) MapStatus status;

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *summary;
@property (strong, nonatomic) NSDate *fileDate;
@property (strong, nonatomic) NSDate *serverDate;
@property (weak, nonatomic) id <MapMonitoring> delegate;

- (BOOL) isOutdated;
- (BOOL) isOrphan;

- (void) download;
- (void) unload;

+ (Map *) randomMap; //for testing purposes

@end
