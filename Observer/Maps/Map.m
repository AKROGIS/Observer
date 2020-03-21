//
//  Map.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "Map.h"
#import "MapCollection.h"
#import "AKRFormatter.h"
#import "NSDate+Formatting.h"
#import "NSURL+isEqualToURL.h"
#import "NSURL+unique.h"
#import "AKRLog.h"

@interface Map()

@property (nonatomic, strong, readonly) NSURL *plistURL;

//A private dictionary of map properties
@property (nonatomic, strong) NSDictionary *properties;

//This will change when a map is downloaded
@property (nonatomic, strong, readwrite) NSURL *tileCacheURL;

//Loading resources
@property (nonatomic,         readwrite) BOOL isThumbnailLoaded;
@property (nonatomic,         readwrite) BOOL isTileCacheLoaded;
@property (nonatomic, strong, readwrite) UIImage *thumbnail;
@property (nonatomic, strong, readwrite) AGSArcGISTiledLayer *tileCache;

//TODO: #6 move to NSOperation
@property (nonatomic, readwrite) BOOL downloading;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionTask *downloadTask;

@end

@implementation Map

- (instancetype)initWithProperties:(NSDictionary *)properties
{
    if (!properties) {
        return nil;
    }
    self = [super init];
    if (self) {
        _properties = properties;
    }
    return self;
}

- (instancetype)initWithCachedPropertiesName:(NSString *)name
{
    // Prior to version 1.0.0, name was an absolute path URL cached in settings.
    // This URL was wrong after an update (the app directory gets renamed).
    // Since this method is only called with a name from settings (that the app wrote), we know what it will look like
    // if it has a "/" it is an absolute path, remove all but the last component
    if (name == nil || name.length == 0) {
        AKRLog(@"Aborting initWithCachedPropertiesName: No name was provided");
        return nil;
    }
    if ([name containsString:@"/"]) {
        NSURL *url = [NSURL URLWithString:name];
        NSString *lastPathComponent = url.lastPathComponent;
        if (lastPathComponent == nil) {
            AKRLog(@"Aborting initWithCachedPropertiesName: %@. Name (%@) has a '/' but is not a valid URL.", url, name);
            return nil;
        }
        name = lastPathComponent;
    }
    NSURL *url = [[Map plistLocation] URLByAppendingPathComponent:name];
    NSString *path = url.path;
    BOOL fileExistsAtPath = (path == nil) ? NO : [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!fileExistsAtPath) {
        AKRLog(@"Aborting initWithCachedPropertiesURL: %@. File not found.", url);
        return nil;
    }

    self = [self initWithProperties:[NSDictionary dictionaryWithContentsOfURL:url]];
    if (self) {
         _plistURL = url;
    }
    return self;
}

- (instancetype)initWithRemoteProperties:(NSDictionary *)properties
{
    NSMutableDictionary *newProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
    newProperties[kCachedThumbUrlKey] = [Map generateThumbnailURL].lastPathComponent;
    self = [self initWithProperties:[newProperties copy]];
    if (self) {
        _plistURL = [Map generatePlistURL];
        [newProperties writeToURL:_plistURL atomically:YES];
    }
    return self;
}

- (instancetype)initWithTileCacheURL:(NSURL *)url
{
    //This will only be called by the app delegate or the map collection with a File URL in the Documents folder
    NSString *path = url.path;
    NSDictionary *fileAttributes = (path == nil) ? nil : [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (!fileAttributes) {
        return nil;
    }
    AGSArcGISTiledLayer *tileCache =[Map loadTileCacheAtURL:url];
    // loadTileCacheAtURL will check tilecache properties and return nil if invalid.
    if (!tileCache) {
        return nil;
    }
    //create a properties dictionary based on solely on the tilecache contents
    NSMutableDictionary *newProperties = [NSMutableDictionary new];
    newProperties[kTitleKey] = url.lastPathComponent.stringByDeletingPathExtension;
    newProperties[kAuthorKey] = @"Unknown";
    newProperties[kDateKey] = [fileAttributes fileCreationDate];  //TODO: #92 Get the date from the esriinfo.xml file in the zipped tpk
    newProperties[kSizeKey] = @([fileAttributes fileSize]);
    newProperties[kUrlKey] = url.lastPathComponent;
    //kRemoteThumbUrlKey - not available or required
    newProperties[kCachedThumbUrlKey] = [Map generateThumbnailURL].lastPathComponent;
    newProperties[kDescriptionKey] = @"Not available."; //TODO: #92 get the description from the esriinfo.xml file in the zipped tpk
    AGSEnvelope *extents = tileCache.tileCache.fullExtent;
    if (!extents) {
        return nil;
    }
    extents = (AGSEnvelope *)[AGSGeometryEngine projectGeometry:extents toSpatialReference:[AGSSpatialReference WGS84]];
    newProperties[kXminKey] = @(extents.xMin);
    newProperties[kYminKey] = @(extents.yMin);
    newProperties[kXmaxKey] = @(extents.xMax);
    newProperties[kYmaxKey] = @(extents.yMax);

    self = [self initWithProperties:[newProperties copy]];
    if (self) {
        _tileCache = tileCache;
        self.isTileCacheLoaded = YES;
        _thumbnail = tileCache.tileCache.thumbnail;
        self.isThumbnailLoaded = YES;
        [Map saveImage:_thumbnail toURL:self.cachedThumbnailURL];
        _plistURL = [Map generatePlistURL];
        [newProperties writeToURL:_plistURL atomically:YES];
    }
    return self;
}

- (instancetype)initWithTileCacheURL:(NSURL *)url name:(NSString *)name author:(NSString *)author date:(NSDate *)date description:(NSString *)description
{
    self = [self initWithTileCacheURL:url];
    if (self) {
        NSMutableDictionary *newProperties = [NSMutableDictionary dictionaryWithDictionary:self.properties];
        if (name) {
            newProperties[kTitleKey] = name;
        }
        if (author) {
            newProperties[kAuthorKey] = author;
        }
        if (date) {
            newProperties[kDateKey] = date;
        }
        if (date) {
            newProperties[kDescriptionKey] = description;
        }
        self.properties = [newProperties copy];
        [self.properties writeToURL:self.plistURL atomically:YES];
    }
    return self;
}

//Alert: will block for filesystem IO
+ (NSURL *)generatePlistURL
{
    NSURL *folder = [Map plistLocation];
    NSString *path = folder.path;
    BOOL fileExistsAtPath = (path == nil) ? NO : [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (path != nil && !fileExistsAtPath) {
        [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [folder URLByAppendingPathComponent:@"map.plist"].URLByUniquingPath;
    //The new URL will be written to right away.
}

+ (NSURL *)plistLocation
{
    NSURL *library = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *folder = [library URLByAppendingPathComponent:@"Map Properties" isDirectory:YES];
    return folder;
}

- (NSString *)plistName
{
    return self.plistURL.lastPathComponent;
}

//Alert: will block for filesystem IO
+ (NSURL *)generateThumbnailURL
{
    //remove the old folder
    NSURL *oldFolder = [Map oldThumbsLocation];
    NSString *oldPath = oldFolder.path;
    BOOL fileExistsAtOldPath = (oldPath == nil) ? NO : [[NSFileManager defaultManager] fileExistsAtPath:oldPath];
    if (fileExistsAtOldPath) {
        [[NSFileManager defaultManager] removeItemAtURL:oldFolder error:nil];
    }
    //create the new folder
    NSURL *folder = [Map thumbsLocation];
    NSString *path = folder.path;
    BOOL fileExistsAtPath = (path == nil) ? NO : [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (path != nil && !fileExistsAtPath) {
        [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSURL *newUrl = [folder URLByAppendingPathComponent:@"thumbnail.png"].URLByUniquingPath;
    //Since thumbnails will not be written right away, and new maps may get created in between,
    //we need to write a sentinal to disk at this URL, so another map will not try to us the same URL
    path = newUrl.path;
    if (path != nil) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    }
    return newUrl;
}

+ (NSURL *)oldThumbsLocation
{
    NSURL *library = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *folder = [library URLByAppendingPathComponent:@"mapthumbs" isDirectory:YES];
    return folder;
}

+ (NSURL *)thumbsLocation
{
    NSURL *library = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *folder = [library URLByAppendingPathComponent:@"Map Thumbnails" isDirectory:YES];
    return folder;
}




#pragma mark - Property Accessors

- (NSString *)title
{
    id item = self.properties[kTitleKey];
    return [item isKindOfClass:[NSString class]] ? item : @"No Title";
}

- (NSString *)author
{
    id item = self.properties[kAuthorKey];
    return [item isKindOfClass:[NSString class]] ? item : @"Unknown";
}

- (NSDate *)date
{
    id item = self.properties[kDateKey];
    return [item isKindOfClass:[NSDate class]] ? item : ([item isKindOfClass:[NSString class]] ? [AKRFormatter dateFromISOString:item] : nil);
}

- (unsigned long long)byteCount
{
    id item = self.properties[kSizeKey];
    return [item isKindOfClass:[NSNumber class]] ? [item unsignedLongLongValue] : 0;
}

@synthesize tileCacheURL = _tileCacheURL;

- (NSURL *)tileCacheURL
{
    if (_tileCacheURL == nil) {
        id item = self.properties[kUrlKey];
        // item is either a string rep of an absolute path to a remote URL, OR
        // the absolute path file URL to a local TPK, which is invalid after an update (< v1.0.0), OR
        // the lastPathComponent (v1.0.0+)
        if (item == nil || ![item isKindOfClass:[NSString class]]) {
            AKRLog(@"A string property for the cachedTpkURL could not be found");
            return nil;
        }
        NSString * name = (NSString *)item;
        if (name.length == 0) {
            AKRLog(@"The name of the cachedTpkURL is empty");
            return nil;
        }
        NSURL *localRoot = [MapCollection documentsDirectory];
        if ([name containsString:@"/"]) {
            // could be an old style local name, or a remote URL
            NSURL *url = [NSURL URLWithString:name];
            if (url.isFileURL) {
                NSString *lastPathComponent = url.lastPathComponent;
                if (lastPathComponent == nil) {
                    AKRLog(@"Bad cachedTpkURL: %@. Name (%@) has a '/' but is not a valid URL.", url, name);
                    return nil;
                }
                _tileCacheURL = [localRoot URLByAppendingPathComponent:lastPathComponent];
            } else {
                _tileCacheURL = url;
            }
        } else {
            _tileCacheURL = [localRoot URLByAppendingPathComponent:name];
        }
    }
    return _tileCacheURL;
}

//Alert: Mutating function
//Alert: will block for IO
- (void)setTileCacheURL:(NSURL *)tileCacheURL
{
    if (![tileCacheURL isEqualToURL:self.tileCacheURL]) {
        NSMutableDictionary *newProperties = [NSMutableDictionary dictionaryWithDictionary:self.properties];
        newProperties[kUrlKey] = tileCacheURL.isFileURL ? tileCacheURL.lastPathComponent : tileCacheURL.absoluteString;
        self.properties = [newProperties copy];
        [newProperties writeToURL:self.plistURL atomically:YES];
        _tileCacheURL = tileCacheURL;
    }
}

- (NSURL *)remoteThumbnailURL
{
    id item = self.properties[kRemoteThumbUrlKey];
    return [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
}

- (NSURL *)cachedThumbnailURL
{
    id item = self.properties[kCachedThumbUrlKey];
    // item is the lastPathComponent; prior to v1.0.0, it was the absolute path (which is invalid after an update)
    if (item == nil || ![item isKindOfClass:[NSString class]]) {
        AKRLog(@"A string property for the cachedThumbnailURL could not be found");
        return nil;
    }
    NSString * name = (NSString *)item;
    if (name.length == 0) {
        AKRLog(@"The name of the cachedThumbnailURL is empty");
        return nil;
    }
    if ([name containsString:@"/"]) {
        NSURL *url = [NSURL URLWithString:name];
        NSString *lastPathComponent = url.lastPathComponent;
        if (lastPathComponent == nil) {
            AKRLog(@"Bad cachedThumbnailURL: %@. Name (%@) has a '/' but is not a valid URL.", url, name);
            return nil;
        }
        name = lastPathComponent;
    }
    return [[Map thumbsLocation] URLByAppendingPathComponent:name];
}

- (NSString *)mapNotes
{
    id item = self.properties[kDescriptionKey];
    return [item isKindOfClass:[NSString class]] ? item : nil;
}

@synthesize extents = _extents;

- (AGSEnvelope *)extents {
    if (!_extents) {
        id item =  self.properties[kXminKey];
        if (![item isKindOfClass:[NSNumber class]]) {
            return nil;
        }
        double xmin = [item doubleValue];
        item =  self.properties[kYminKey];
        if (![item isKindOfClass:[NSNumber class]]) {
            return nil;
        }
        double ymin = [item doubleValue];
        item =  self.properties[kXmaxKey];
        if (![item isKindOfClass:[NSNumber class]]) {
            return nil;
        }
        double xmax = [item doubleValue];
        item =  self.properties[kYmaxKey];
        if (![item isKindOfClass:[NSNumber class]]) {
            return nil;
        }
        double ymax = [item doubleValue];
        if (xmin < xmax && ymin < ymax) {
            _extents = [[AGSEnvelope alloc] initWithXMin:xmin yMin:ymin xMax:xmax yMax:ymax spatialReference:[AGSSpatialReference WGS84]];
        }
    }
    return _extents;
}




#pragma mark - AKRTableViewItem

- (NSString *)subtitle
{
    return [NSString stringWithFormat:@"Author: %@", self.author];
}

- (NSString *)subtitle2
{
    if (self.isDownloading) {
        return @"Downloading...";
    } else {
        return [NSString stringWithFormat:@"Date: %@, Size: %@", self.date.stringWithMediumDateFormat, [AKRFormatter stringFromBytes:self.byteCount]];
    }
}




#pragma mark - Load Thumbnail

//Alert: may call a mutating function
//Alert: may block for IO
- (UIImage *)thumbnail
{
    if (!_thumbnail && !self.isThumbnailLoaded) {
        [self loadThumbnail];
    }
    return _thumbnail;
}

//Alert: will call a mutating function
- (void)loadThumbnailWithCompletionHandler:(void (^)(BOOL success))completionHandler {
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
        [self loadThumbnail];
        if (completionHandler) {
            completionHandler(self.thumbnail != nil);
        }
    });
}

//Alert: Mutating function
//Alert: will block for IO
- (void)loadThumbnail {
    UIImage *thumbnail = nil;
    NSString *path = self.cachedThumbnailURL.path;
    if (path != nil && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        thumbnail = [Map loadThumbnailAtURL:self.cachedThumbnailURL];
    }
    if (!thumbnail) {
        thumbnail = [Map loadThumbnailAtURL:self.remoteThumbnailURL];
        if (thumbnail) {
            [Map saveImage:thumbnail toURL:self.cachedThumbnailURL];
        }
    }
    _thumbnail = thumbnail;
    self.isThumbnailLoaded = YES;
}

//Alert: will block for IO
+ (UIImage *)loadThumbnailAtURL:(NSURL *)url
{
    if (url.isFileURL) {
        NSData *data = [NSData dataWithContentsOfURL:url];
        return (data == nil) ? nil : [[UIImage alloc] initWithData:data];
    } else {
        //TODO: #6 do this transfer in an NSOperation Queue
        //TODO: #6 need to deal with various network errors
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        NSData *data = [NSData dataWithContentsOfURL:url];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        return (data == nil) ? nil : [[UIImage alloc] initWithData:data];
    }
}

//Alert: will block for IO
+ (void)saveImage:(UIImage *)image toURL:(NSURL *)url
{
    if (url.isFileURL) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        [UIImagePNGRepresentation(image) writeToURL:url atomically:YES];
    }
}




#pragma mark - Load TileCache

//Alert: may call a mutating function
//Alert: may block for IO
- (AGSArcGISTiledLayer *)tileCache
{
    if (!_tileCache && !self.isTileCacheLoaded) {
        [self loadTileCache];
    }
    return _tileCache;
}

//Alert: Mutating function
//Alert: will block for IO
- (void)loadTileCache {
    _tileCache = [Map loadTileCacheAtURL:self.tileCacheURL];
    self.isTileCacheLoaded = _tileCache != nil;
}

//Alert: will block for IO; Timing on an iPad Air2 was <.03 seconds
+ (AGSArcGISTiledLayer *)loadTileCacheAtURL:(NSURL *)url
{
    //with ArcGIS 10.2.5 tilecache is non-null even when initilazing with a bad file
    //However accessing properties like fullEnvelope will yield an EXC_BAD_ACCESS if it is invalid
    //We do the sanity check now to avoid any surprises later.
    //July 2016 Update: this is not always true.  I'm getting some crash reports on the alloc/init line
    //So I am moving it inside the try/catch. The online documentation is silent on this:
    //https://developers.arcgis.com/ios/10-2/api-reference/interface_a_g_s_local_tiled_layer.html
    NSString *path = url.path;
    if (path != nil && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        @try {
            AGSArcGISTiledLayer *tiles = [[AGSArcGISTiledLayer alloc] initWithURL:url];
            if (tiles.tileCache && tiles.tileCache.fullExtent && !tiles.tileCache.fullExtent.isEmpty) {
                return tiles;
            }
            AKRLog(@"missing or empty envelope in tile cache %@",url);
        }
        @catch (NSException *exception) {
            AKRLog(@"Exception %@ when checking tile cache %@",exception,url);
        }
    } else {
        AKRLog(@"tile cache not found at path %@",url);
    }
    return nil;
}




#pragma mark - public methods

- (BOOL)isEqualToMap:(Map *)other
{
    // need to be careful with null properties.
    // without the == check, two null properties will be not equal
    if (!other) {
        return NO;
    }
    return [self.tileCacheURL isEqualToURL:other.tileCacheURL] ||
           ((self.byteCount == other.byteCount) &&
            ((self.author == other.author) || [self.author isEqual:other.author]) &&
            ((self.date == other.date) || [self.date isEqual:other.date]));
}

- (BOOL)isEqualToRemoteProperties:(NSDictionary *)remoteMapProperties
{
    //Equality is not well defined here, but I am trying to answer this question:
    //Is the tilecache represented by the remote properties the same as a tilecache that I have already memorized?

    //Metadata equality
    //Equal if the title, author and date are the same. (even if the content (URL/size) maybe different)
    id remoteTitle = remoteMapProperties[kTitleKey];
    BOOL titleMatch = (remoteTitle != nil && self.title != nil && [self.title isEqualToString:remoteTitle]) || (remoteTitle == nil && self.title == nil);
    if (titleMatch) { // Check Author
        id remoteAuthor = remoteMapProperties[kAuthorKey];
        BOOL authorMatch = (remoteAuthor != nil && self.author != nil && [self.author isEqualToString:remoteAuthor]) || (remoteAuthor == nil && self.author == nil);
        if (authorMatch) {  //Check Date
            id item = remoteMapProperties[kDateKey];
            NSDate *remoteDate = [item isKindOfClass:[NSDate class]] ? item : ([item isKindOfClass:[NSString class]] ? [AKRFormatter dateFromISOString:item] : nil);
            BOOL dateMatch = (remoteDate != nil && self.date != nil && [self.date isEqualToDate:remoteDate]) || (remoteDate == nil && self.date == nil);
            if (dateMatch) {
                return YES;
            }
        }
    }
    //Content equality
    //Equal if the name (last componenet of the URL) and the bytecount are the same. (even if the Title/Author/Date are different)
    id remoteSize = remoteMapProperties[kSizeKey];
    unsigned long long remoteByteCount = [remoteSize isKindOfClass:[NSNumber class]] ? [remoteSize unsignedLongLongValue] : 0;
    BOOL byteCountMatch = self.byteCount == remoteByteCount;
    if (byteCountMatch) { // Check Name
        NSString *thisName = self.tileCacheURL.lastPathComponent;
        id item = remoteMapProperties[kUrlKey];
        NSURL *remoteURL = [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
        NSString *remoteName = remoteURL.lastPathComponent;
        BOOL nameMatch = (remoteName != nil && thisName != nil && [thisName isEqualToString:remoteName]) || (remoteName == nil && thisName == nil);
        if (nameMatch) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)shouldUpdateToRemoteProperties:(NSDictionary *)remoteMapProperties
{
    //Any of the properties may have changed. to answer this, I would need to check each property
    //In addition the resource at the end of the thumnail URL may have been updated, and I have no way to determine this
    //Unless this is a problem, I will assume the worst.
    //Also update local items if the author is unknown (probably came from a local tpk file)
    return !self.isLocal || [self.author isEqualToString:@"Unknown"];
}

//Alert: Mutating function
//Alert: will block for IO
- (void)updateWithRemoteProperties:(NSDictionary *)remoteMapProperties
{
    NSMutableDictionary *newProperties = [NSMutableDictionary dictionaryWithDictionary:remoteMapProperties];
    //the cachedThumbnailURL, and the tileCacheURL are the only properties that I might have changed.
    newProperties[kCachedThumbUrlKey] = self.properties[kCachedThumbUrlKey];
    if (self.isLocal) {
        //save the local URL, so we do not revert to a remote tilecache
        newProperties[kUrlKey] = self.properties[kUrlKey];
    }
    //clear the contents of the thumbnail, so it will be reloaded;
    //do not remove the file, else the saved name may get re-used
    [[NSFileManager defaultManager] removeItemAtURL:self.cachedThumbnailURL error:nil];
    NSString *path = self.cachedThumbnailURL.path;
    if (path != nil) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    }
    _thumbnail = nil;
    self.isThumbnailLoaded = NO;
    _extents = nil;
    self.properties = [newProperties copy];
    [newProperties writeToURL:_plistURL atomically:YES];
}

- (BOOL)isLocal
{
    return self.tileCacheURL.isFileURL;
}

- (AKRAngleDistance *)angleDistanceFromLocation:(CLLocation *)location
{
    return [AKRAngleDistance angleDistanceFromLocation:location toGeometry:self.extents];
}

- (double)areaInKilometers
{
    if (!self.extents || self.extents.isEmpty) {
        return -1;
    }
    double area = [AGSGeometryEngine areaOfGeometry:self.extents];
    AGSAreaUnit *unit = (AGSAreaUnit *)self.extents.spatialReference.unit;
    return [unit convert:area toUnit:[AGSAreaUnit unitWithUnitID:AGSAreaUnitIDSquareKilometers]];
}

//Alert: Mutating function
//Alert: Will block for IO
- (void)deleteFromFileSystem
{
    if (self.isLocal) {
        [[NSFileManager defaultManager] removeItemAtURL:self.tileCacheURL error:nil];
    }
    [[NSFileManager defaultManager] removeItemAtURL:self.cachedThumbnailURL error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:self.plistURL error:nil];
}




#pragma mark - download
//TODO: #6 move this to a NSOperation

- (NSURLSession *)session
{
    static NSURLSession *backgroundSession = nil;
    
    if (!_session) {
        NSURLSessionConfiguration *configuration;
        if (self.isBackground) {
            if (!backgroundSession) {
                configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"gov.nps.observer.BackgroundDownloadSession"];
                backgroundSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
            }
            _session = backgroundSession;
        } else {
            configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        }
    }
    return _session;
}

- (void)startDownload
{
    NSURLRequest *request = [NSURLRequest requestWithURL:self.tileCacheURL];
    self.downloadTask = [self.session downloadTaskWithRequest:request];
    self.downloadPercentComplete = 0;
    self.downloading = YES;
    [self.downloadTask resume];
    [MapCollection startDownloading];
}

- (void)cancelDownload
{
    [self.downloadTask cancel];
    self.downloading = NO;
    [MapCollection canceledDownloading];
}




#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    //TODO: #6 implement method to support resume download (for pause or lost connection)
    AKRLog(@"did resume download");
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (downloadTask == self.downloadTask && self.downloadProgressAction){
        self.downloadPercentComplete = totalBytesWritten/totalBytesExpectedToWrite;
        self.downloadProgressAction((double)totalBytesWritten, (double)totalBytesExpectedToWrite);
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    self.downloading = NO;
    if (downloadTask.state == NSURLSessionTaskStateCanceling) {
        return;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (!self.destinationURL) {
        NSURL *documentsDirectory = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        NSURL *originalURL = downloadTask.originalRequest.URL;
        NSString *name = originalURL.lastPathComponent;
        self.destinationURL = (name == nil) ? nil : [documentsDirectory URLByAppendingPathComponent:name];
    }
    NSString *path = self.destinationURL.path;
    BOOL fileExistsAtPath = (path == nil) ? NO : [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (self.destinationURL != nil && fileExistsAtPath) {
        if (self.canReplace) {
            [fileManager removeItemAtURL:self.destinationURL error:NULL];
        } else {
            self.destinationURL = self.destinationURL.URLByUniquingPath;
        }
    }
    BOOL success = (location == nil || self.destinationURL == nil) ? NO : [fileManager copyItemAtURL:location toURL:self.destinationURL error:nil];
    [MapCollection finishedDownloading];
    if (success) {
        self.tileCacheURL = self.destinationURL;
    }
    if (self.downloadCompletionAction) {
        self.downloadCompletionAction(success);
    }
}




#pragma mark - NSObject overrides

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ by %@, dated: %@", self.title, self.author, self.date.stringWithMediumDateFormat];
}

@end
