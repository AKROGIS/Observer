//
//  Map.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AKRTableViewItem.h"
#import "AKRAngleDistance.h"

#define MAP_EXT @"tpk"

//Key strings and expected value types for the initialization dictionary
#define kTitleKey           @"name"           //NSString
#define kAuthorKey          @"author"         //NSString
#define kDateKey            @"date"           //NSDate or NSString as yyyy-mm-dd
#define kSizeKey            @"size"           //NSNumber -> NSUInteger
#define kUrlKey             @"url"            //NSString -> NSURL
#define kRemoteThumbUrlKey  @"thumbnail"      //NSString -> NSURL
#define kCachedThumbUrlKey  @"localThumbnail" //NSString -> NSURL (not in remote plist)
#define kDescriptionKey     @"description"    //NSString
#define kXminKey            @"xmin"           //NSNumber -> float (WGS84 decimal degrees)
#define kXmaxKey            @"xmax"           //NSNumber -> float (WGS84 decimal degrees)
#define kYminKey            @"ymin"           //NSNumber -> float (WGS84 decimal degrees)
#define kYmaxKey            @"ymax"           //NSNumber -> float (WGS84 decimal degrees)



@interface Map : NSObject <AKRTableViewItem, NSURLSessionDownloadDelegate>

//Initializers
//============
// Designated
//-----------
- (id)initWithProperties:(NSDictionary *)properties;
- (id) init __attribute__((unavailable("Must use initWithProperties: or other initializer instead.")));

//Convenience
//-----------
//Initialize with a file URL to a plist with a dictionary of property values
//  Will block while the property list is read from the filesystem
- (id)initWithCachedPropertiesURL:(NSURL *)url;
//Initialize with a dictionary of remote property values
//  Assumes that the remote properties describe a new map, and therefore it
//  creates a local URL for caching the thumbnail, and caches the properties as a local plist
//  Will block while the plist is saved to disk
- (id)initWithRemoteProperties:(NSDictionary *)properties;
//Initialize with the URL to a local tile cache
//Assumes that the tilecache is new, and creates new thumbnail and properties caches
//  Creates a property list from the values in the tilecache, and caches the properties as a local plist
//  Will return nil if the tileCache is not a valid local tilecache
//  Will block while tileCache is loaded and the plist is written
- (id)initWithTileCacheURL:(NSURL *)url;
//Initialize same as above, but with overrides for several properties not easily obtained from the tilecache
- (id)initWithTileCacheURL:(NSURL *)url name:(NSString *)name author:(NSString *)author date:(NSDate *)date description:(NSString *)description;
//============



@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *author;
@property (nonatomic, strong, readonly) NSDate *date;
@property (nonatomic,         readonly) unsigned long long byteCount;
@property (nonatomic, strong, readonly) NSURL *tileCacheURL;
@property (nonatomic, strong, readonly) NSURL *remoteThumbnailURL;
@property (nonatomic, strong, readonly) NSURL *cachedThumbnailURL;
@property (nonatomic, strong, readonly) NSString *mapNotes;
@property (nonatomic, strong, readonly) AGSEnvelope *extents;

@property (nonatomic, strong, readonly) NSURL *plistURL;

//Accessing the following properties will block (loading resource) on the first call
//  The properties may be preloaded in some initialization scenarios
//Use the boolean checks and loaders it you want more control.
//  NOTE: the isLoaded BOOLs designate that the load was attempted, not that it was successful
//        check the resource property for nullity to determine success if isLoaded is YES
//        if you want to try again, you must call the version with the completion handler
@property (nonatomic, strong, readonly) UIImage *thumbnail;
@property (nonatomic, strong, readonly) AGSLocalTiledLayer *tileCache;

@property (nonatomic,         readonly) BOOL isThumbnailLoaded;
@property (nonatomic,         readonly) BOOL isTileCacheLoaded;
- (void)loadThumbnailWithCompletionHandler:(void (^)(BOOL success))completionHandler;
- (void)loadTileCacheWithCompletionHandler:(void (^)(BOOL success))completionHandler;



//YES if two Maps are the same (same size, title, author and date)
//    do not compare urls, because the same Map will have either a local, or a server url
- (BOOL)isEqualToMap:(Map *)Map;

//Methods for Syncing with Server
- (BOOL)isEqualToRemoteProperties:(NSDictionary *)remoteMapProperties;
- (BOOL)shouldUpdateToRemoteProperties:(NSDictionary *)remoteMapProperties;
- (void)updateWithRemoteProperties:(NSDictionary *)remoteMapProperties;


// Additional info for the view controllers
- (AKRAngleDistance *)angleDistanceFromLocation:(CLLocation *)location;
- (double)areaInKilometers;
//YES if the Map is available locally, NO otherwise;
- (BOOL)isLocal;

// download the Protocol from the remote URL to a local file...
- (void)startDownload;
- (void)cancelDownload;
- (BOOL)isDownloading;

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
@property (nonatomic, copy) void(^downloadCompletionAction)(BOOL success);
// The percent complete of the download, saved incase the the popover is dismissed, and then re-presented
@property (nonatomic) double downloadPercentComplete;

//Delete all map data, thumbnails, and cached properties from the file system.
- (void)deleteFromFileSystem;

@end
