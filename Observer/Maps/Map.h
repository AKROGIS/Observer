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

//Key strings and expected value types for the initialization dictionary
#define kTitleKey         @"name"        //NSString
#define kAuthorKey        @"author"      //NSString
#define kDateKey          @"date"        //NSDate or NSString as yyyy-mm-dd
#define kDescriptionKey   @"description" //NSString
#define kSizeKey          @"size"        //NSNumber -> NSUInteger
#define kXminKey          @"xmin"        //NSNumber -> float (WGS84 decimal degrees)
#define kXmaxKey          @"xmax"        //NSNumber -> float (WGS84 decimal degrees)
#define kYminKey          @"ymin"        //NSNumber -> float (WGS84 decimal degrees)
#define kYmaxKey          @"ymax"        //NSNumber -> float (WGS84 decimal degrees)
#define kThumbnailUrlKey  @"thumbnail"   //NSString -> NSURL


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

// Designated initializer
// This initializer should not be called by clients, as it returns a useless map.  Instead, use the convenience initializers
- (id)initWithURL:(NSURL *)url;
- (id) init __attribute__((unavailable("Must use initWithURL: instead.")));

//Convenience initializers
//Initialize with a dictionary of property values
- (id)initWithDictionary:(NSDictionary *)dictionary;
//Initialize with the contents of a local tile, will block while tileCache is loaded,
//and will return nil if the tileCache is not local, not found, or not valid
- (id)initWithLocalTileCache:(NSURL *)url;

//YES if two Maps are the same (same size, title, author and date)
//    do not compare urls, because the same Map will have either a local, or a server url
- (BOOL)isEqualToMap:(Map *)Map;

//YES if the survey is valid
- (BOOL) isValid;

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
@property (nonatomic, copy) void(^downloadCompletionAction)(Map *newMap);
// The percent complete of the download, saved incase the the popover is dismissed, and then re-presented
@property (nonatomic) float downloadPercentComplete;

@end
