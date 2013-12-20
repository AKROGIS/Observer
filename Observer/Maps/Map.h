//
//  Map.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ArcGIS/ArcGIS.h>
#import "AKRTableViewItem.h"
#import "AKRAngleDistance.h"

#define MAP_EXT @"tpk"

@interface Map : NSObject <NSCoding, AKRTableViewItem, NSURLSessionDownloadDelegate>

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *description;
@property (nonatomic, strong, readonly) NSString *author;
@property (nonatomic, strong, readonly) NSDate *date;
@property (nonatomic, readonly) NSUInteger byteCount;
@property (nonatomic, readonly) AGSEnvelope *extents;
@property (nonatomic, strong, readonly) NSURL *thumbnailUrl;

//The following properties will block (reading data from the network/filessytem)
//To avoid the potential delay, call openXXXWithCompletionHandler first.
@property (nonatomic, strong, readonly) UIImage *thumbnail;
@property (nonatomic, strong, readonly) AGSLocalTiledLayer *tileCache;

- (void)openThumbnailWithCompletionHandler:(void (^)(BOOL success))completionHandler;
- (void)openTileCacheWithCompletionHandler:(void (^)(BOOL success))completionHandler;

//designated initializer
- (id)initWithURL:(NSURL *)url;
- (id) init __attribute__((unavailable("Must use initWithURL: instead.")));

//Convenience initializers
- (id)initWithDictionary:(NSDictionary *)dictionary;
- (id)initWithLocalTileCache:(NSURL *)url;

//YES if two Maps are the same (same title, version and date)
//    do not compare urls, because the same Map will have either a local, or a server url
- (BOOL)isEqualtoMap:(Map *)Map;

// Helpers for details view
// TODO: move these to categories or to the details view controller
- (NSString *)byteSizeString;
- (NSString *)arealSizeString;

// Additional info for details view
- (AKRAngleDistance *)angleDistanceFromLocation:(CLLocation *)location;

//YES if the Map is available locally, NO otherwise;
- (BOOL)isLocal;

// download the Map from the remote URL to a local file...
- (void)prepareToDownload;
- (void)startDownload;
- (void)stopDownload;
- (BOOL)isDownloading;

//properties to support downloading
//TODO: move these to a generic NSOperation
@property (nonatomic) BOOL isBackground;
@property (nonatomic) BOOL canReplace;
@property (nonatomic, strong) NSURLSession *session;
//@property (nonatomic, strong) NSURL *sourceURL;
@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, copy) void(^progressAction)(double bytesWritten, double bytesExpected);
@property (nonatomic, copy) void(^completionAction)(NSURL *imageUrl, BOOL success);


@end
