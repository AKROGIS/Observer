//
//  Map.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AKRTableViewItem.h"
#import <ArcGIS/ArcGIS.h>
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

// Helpers for details view
- (NSString *)byteSizeString;
- (NSString *)arealSizeString;
- (AKRAngleDistance *)angleDistanceFromLocation:(CLLocation *)location;

//YES if the Map is available locally, NO otherwise;
- (BOOL)isLocal;

//title and date will block (reading values from the filessytem) if the state is unborn.
//To avoid the potential delay, call readPropertiesWithCompletionHandler first

//The following methods will block (reading data from the filessytem)
//To avoid the potential delay, call openPropertiesWithCompletionHandler first
@property (nonatomic, strong, readonly) UIImage *thumbnail;
//FIXME: get correct type for tilecache and validate usage
@property (nonatomic, strong, readonly) AGSLocalTiledLayer *tileCache;


//YES if two Maps are the same (same title, version and date)
//    do not compare urls, because the same Map will have either a local, or a server url
- (BOOL)isEqualtoMap:(Map *)Map;

//designated initializer
//- (id) initWithURL:(id)url title:(id)title author:(id)author date:(id)date size:(id)size description:(id)description thumbnail:(id)thumbnail xmin:(id)xmin ymin:(id)ymin xmax:(id)xmax ymax:(id)ymax;
- (id)initWithURL:(NSURL *)url;
- (id)initWithDictionary:(NSDictionary *)dictionary;
- (id)initWithLocalTileCache:(NSURL *)url;
- (id) init __attribute__((unavailable("Must use initWithURL: instead.")));

// download the Map from the remote URL to a local file...
- (void)prepareToDownload;
- (BOOL)isDownloading;
//- (BOOL)downloadToURL:(NSURL *)url;

- (void)openThumbnailWithCompletionHandler:(void (^)(BOOL success))completionHandler;


@property (nonatomic) BOOL isBackground;
@property (nonatomic) BOOL canReplace;
@property (nonatomic, strong) NSURLSession *session;
//@property (nonatomic, strong) NSURL *sourceURL;
@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, copy) void(^progressAction)(double bytesWritten, double bytesExpected);
@property (nonatomic, copy) void(^completionAction)(NSURL *imageUrl, BOOL success);

- (void) startDownload;
- (void) stopDownload;

@end
