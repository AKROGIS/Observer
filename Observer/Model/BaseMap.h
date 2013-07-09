//
//  BaseMap.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>
#import "MapMonitoring.h"

typedef enum {
    MapStatusNormal,
    MapStatusDownloading,
    MapStatusDownloadFailed,
    //MapStatusLoading,  /loading a tileCache from a URL is not async
    MapStatusLoadFailed,
    MapStatusUnLoadFailed
} MapStatus;

//Used when determining if a local cached map is out-of-date, or orphaned
typedef enum {
    ServerStatusUnknown,
    ServerStatusPending,
    ServerStatusUnavailable,
    ServerStatusResolved,
    ServerStatusNotApplicable,  //No server URL
} ServerStatus;

@interface BaseMap : NSObject

//designated initializer
- (id) initWithLocalURL:(NSURL *)localURL andServerURL:(NSURL *)serverUrl;
//convenience initilizers
- (id) initWithLocalURL:(NSURL *)localURL;
- (id) initWithServerURL:(NSURL *)serverUrl;
- (id) init; // don't call this - it overrides super init to prevent malformed maps

//These properties should be considered readonly to all objects except the map manager that created (owns) the map
//If you muck with them, you will likely corrupt the map.
@property (strong, nonatomic) NSURL *localURL;
@property (strong, nonatomic) NSURL *serverURL;
@property (strong, nonatomic) AGSLocalTiledLayer *tileCache;
@property (nonatomic) MapStatus status;
@property (nonatomic) ServerStatus serverStatus;


//server dependent properties will always return immediately
//result will be default (nil, or NO) unless serverStatus == ServerStatusResolved
- (BOOL) isOrphan;
- (BOOL) isOutdated;


@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *summary;
@property (strong, nonatomic) NSDate *fileDate;  //Date is in UTC
@property (nonatomic) NSUInteger fileSize;  //Size in KB

//Managing map data
- (void) download; //no effect if the map has been downloaded
- (void) unload;   //deletes the filesystem data, and sets mapStatus => MapStatusLoadFailed
                   //If the map has no serverURL, the owner should delete it.
@property (weak, nonatomic) id <MapMonitoring> delegate;


+ (BaseMap *) randomMap; //for testing purposes

@end
