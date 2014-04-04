//
//  Map.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "Map.h"
#import "MapCollection.h"
#import "NSDate+Formatting.h"
#import "NSURL+unique.h"
#import "Settings.h"
#import "AKRFormatter.h"

#define kCodingVersion    1
#define kCodingVersionKey @"codingversion"
#define kUrlKey           @"url"
#define kExtentsKey       @"extents"

@interface Map()

@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, strong, readwrite) NSString *title;
@property (nonatomic, strong, readwrite) NSString *description;
@property (nonatomic, strong, readwrite) NSString *author;
@property (nonatomic, strong, readwrite) NSDate *date;
@property (nonatomic, readwrite) unsigned long long byteCount;
@property (nonatomic, readwrite) AGSEnvelope *extents;
@property (nonatomic, strong, readwrite) NSURL *localThumbnailUrl;
@property (nonatomic, strong, readwrite) NSURL *remoteThumbnailUrl;

@property (nonatomic, strong, readwrite) UIImage *thumbnail;
@property (nonatomic, strong, readwrite) AGSLocalTiledLayer *tileCache;
@property (nonatomic) BOOL thumbnailIsLoaded;
@property (nonatomic) BOOL tileCacheIsLoaded;

//TODO: move to NSOperation
@property (nonatomic) BOOL downloading;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionTask *downloadTask;

@end

@implementation Map

- (id)initWithURL:(NSURL *)url
{
    if (!url) {
        return nil;
    }
    if (self = [super init]) {
        _url = url;
    }
    return self;
}

- (id)initWithLocalTileCache:(NSURL *)url
{
    Map *map = [self initWithURL:url];
    if (map) {
        if (!map.tileCache) {
            return nil;
        }
        if (map.tileCache.name && ![map.tileCache.name isEqualToString:@""]) {
            map.title = map.tileCache.name;
        } else {
            map.title = [[url lastPathComponent] stringByDeletingPathExtension];
        }
        map.author = @"Unknown"; //TODO: get the author from the esriinfo.xml file in the zipped tpk
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:nil];
        map.byteCount = [fileAttributes fileSize];
        map.date = [fileAttributes fileCreationDate];  //TODO: Get the date from the esriinfo.xml file in the zipped tpk
        map.description = @"Not available."; //TODO: get the description from the esriinfo.xml file in the zipped tpk
        map.localThumbnailUrl = [self createThumbnailUrlForMapName:map.title];
        [UIImagePNGRepresentation(map.tileCache.thumbnail) writeToURL:map.localThumbnailUrl atomically:YES];
        map.thumbnail = map.tileCache.thumbnail;
        map.thumbnailIsLoaded = YES;
        map.extents = map.tileCache.fullEnvelope;
        //exclude map from being backed up to iCloud/iTunes
        [url setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
    return map;
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    id item = dictionary[kUrlKey];
    NSURL *url;
    if ([item isKindOfClass:[NSString class]]) {
        url = [NSURL URLWithString:item];
    }
    if (!url) {
        return nil;
    }
    Map *map = [self initWithURL:url];
    if (map) {
        item = dictionary[kTitleKey];
        map.title = ([item isKindOfClass:[NSString class]] ? item : nil);
        item = dictionary[kDateKey];
        map.date = [item isKindOfClass:[NSDate class]] ? item : ([item isKindOfClass:[NSString class]] ? [AKRFormatter dateFromISOString:item] : nil);
        item = dictionary[kAuthorKey];
        map.author = ([item isKindOfClass:[NSString class]] ? item : nil);
        item =  dictionary[kSizeKey];
        map.byteCount = [item isKindOfClass:[NSNumber class]] ? [item unsignedLongLongValue] : 0;
        item =  dictionary[kDescriptionKey];
        map.description = [item isKindOfClass:[NSString class]] ? item : nil;
        item =  dictionary[kRemoteThumbnailUrlKey];
        map.remoteThumbnailUrl = [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
        item =  dictionary[kXminKey];
        CGFloat xmin = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
        item =  dictionary[kYminKey];
        CGFloat ymin = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
        item =  dictionary[kXmaxKey];
        CGFloat xmax = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
        item =  dictionary[kYmaxKey];
        CGFloat ymax = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
        if (xmin != 0  || ymin != 0 || xmax != 0 || ymax != 0 ) {
            map.extents = [[AGSEnvelope alloc] initWithXmin:xmin ymin:ymin xmax:xmax ymax:ymax spatialReference:[AGSSpatialReference wgs84SpatialReference]];
        }
    }
    return map;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    int version = [aDecoder decodeIntForKey:kCodingVersionKey];
    switch (version) {
        case 1: {
            Map *map = [self initWithURL:[aDecoder decodeObjectForKey:kUrlKey]];
            if (map) {
                map.title = [aDecoder decodeObjectForKey:kTitleKey];
                map.author = [aDecoder decodeObjectForKey:kAuthorKey];
                map.date = [aDecoder decodeObjectForKey:kDateKey];
                map.description = [aDecoder decodeObjectForKey:kDescriptionKey];
                NSNumber *bytes = [aDecoder decodeObjectForKey:kSizeKey];
                map.byteCount = [bytes unsignedIntegerValue];
                map.remoteThumbnailUrl = [aDecoder decodeObjectForKey:kRemoteThumbnailUrlKey];
                map.localThumbnailUrl = [aDecoder decodeObjectForKey:kLocalThumbnailUrlKey];
                map.extents = [[AGSEnvelope alloc] initWithJSON:[aDecoder decodeObjectForKey:kExtentsKey]];
            }
            return map;
        }
        default:
            return nil;
    }
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt:kCodingVersion forKey:kCodingVersionKey];
    [aCoder encodeObject:self.url forKey:kUrlKey];
    [aCoder encodeObject:self.title forKey:kTitleKey];
    [aCoder encodeObject:self.author forKey:kAuthorKey];
    [aCoder encodeObject:self.date forKey:kDateKey];
    [aCoder encodeObject:self.description forKey:kDescriptionKey];
    [aCoder encodeObject:[NSNumber numberWithUnsignedLongLong:self.byteCount] forKey:kSizeKey];
    [aCoder encodeObject:self.remoteThumbnailUrl forKey:kRemoteThumbnailUrlKey];
    [aCoder encodeObject:self.localThumbnailUrl forKey:kLocalThumbnailUrlKey];
    [aCoder encodeObject:[self.extents encodeToJSON] forKey:kExtentsKey];
}


#pragma mark - Lazy property initiallizers

#pragma mark - AKRTableViewItem

@synthesize title = _title;

- (NSString *)title
{
    return _title ? _title : @"No Title";
}

- (NSString *)subtitle
{
    return [NSString stringWithFormat:@"Author: %@", self.author];
}

- (NSString *)subtitle2
{
    if (self.downloading) {
        return @"Downloading...";
    } else {
        return [NSString stringWithFormat:@"Date: %@, Size: %@", [self.date stringWithMediumDateFormat], [AKRFormatter stringFromBytes:self.byteCount]];
    }
}

- (BOOL)hasLoadedThumbnail
{
    return _thumbnailIsLoaded;
}

- (void)loadThumbnailWithCompletionHandler:(void (^)(BOOL success))completionHandler
{
    if (_thumbnail || self.thumbnailIsLoaded) {
        if (completionHandler) {
            completionHandler(_thumbnail != nil);
        }
    }
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
        self->_thumbnail = [self loadThumbnail];
        if (completionHandler) {
            completionHandler(self->_thumbnail != nil);
        }
    });
}

- (UIImage *)thumbnail
{
    return _thumbnail;
}

- (AGSLocalTiledLayer *)tileCache
{
    if (!_tileCache && !self.tileCacheIsLoaded) {
        self.tileCacheIsLoaded = YES;
        //with ArcGIS 10.2 tilecache is always valid, but may fail to loaded into mapView
        //However accessing properties like fullEnvelope will yield an EXC_BAD_ACCESS
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.url.path]) {
            _tileCache = [[AGSLocalTiledLayer alloc] initWithPath:[self.url path]];
        }
    }
    return _tileCache;
}


#pragma mark - public methods

- (BOOL)isEqualToMap:(Map *)other
{
    // need to be careful with null properties.
    // without the == check, two null properties will be not equal
    if (!other) {
        return NO;
    }
    //Comparing URLs is tricky, I am trying to be efficient, and permissive
    BOOL urlMatch = [self.url isEqual:other.url] ||
                    [self.url.absoluteURL isEqual:other.url.absoluteURL] ||
                    [self.url.fileReferenceURL isEqual:other.url.fileReferenceURL];

    return urlMatch ||
           ((self.byteCount == other.byteCount) &&
            ((self.author == other.author) || [self.author isEqual:other.author]) &&
            ((self.date == other.date) || [self.date isEqual:other.date]));
}

- (BOOL) isValid
{
    return !self.isLocal || [[NSFileManager defaultManager] fileExistsAtPath:self.url.path];
}

- (BOOL)isLocal
{
    return self.url.isFileURL;
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
    return [[AGSGeometryEngine defaultGeometryEngine] shapePreservingAreaOfGeometry:self.extents inUnit:AGSAreaUnitsSquareKilometers];
}

- (void)deleteFromFileSystem
{
    [[NSFileManager defaultManager] removeItemAtURL:self.url error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:self.localThumbnailUrl error:nil];
    //TODO: Have the map manage it's own cache, so I don't need call the collection to do the save;
    //[[MapCollection sharedCollection] synchronize];
}




#pragma mark - loaders

- (UIImage *)loadThumbnail
{
    UIImage *thumbnail = nil;
    if (self.localThumbnailUrl && [[NSFileManager defaultManager] fileExistsAtPath:[self.localThumbnailUrl path]]) {
        NSData *data = [NSData dataWithContentsOfURL:self.localThumbnailUrl];
        thumbnail = [[UIImage alloc] initWithData:data];
    } else {
        self.localThumbnailUrl = [self createThumbnailUrlForMapName:self.title];
        //TODO: do this transfer in an NSOperation Queue
        //TODO: need to deal with various network errors
        NSData *data = [NSData dataWithContentsOfURL:self.remoteThumbnailUrl];
        if ([data writeToURL:self.localThumbnailUrl atomically:YES]) {
            thumbnail = [[UIImage alloc] initWithData:data];
        }
    }
    //Update the cache:
    //TODO: Have the map manage it's own cache, so I don't need call the collection to do the save;
    //[[MapCollection sharedCollection] synchronize];

    self.thumbnailIsLoaded = YES;
    return thumbnail;
}

- (NSURL *)createThumbnailUrlForMapName:(NSString *)name
{
    NSURL *library = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *folder = [library URLByAppendingPathComponent:@"mapthumbs" isDirectory:YES];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[folder path]]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSURL *thumb = [[[folder URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"png"] URLByUniquingPath];
    return thumb;
}




#pragma mark - download
//TODO: move this to a NSOperation

- (NSURLSession *)session
{

    static NSURLSession *backgroundSession = nil;
    
    if (!_session) {
        NSURLSessionConfiguration *configuration;
        if (self.isBackground) {
            if (!backgroundSession) {
                configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:@"gov.nps.observer.BackgroundDownloadSession"];
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
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    self.downloadTask = [self.session downloadTaskWithRequest:request];
    self.downloadPercentComplete = 0;
    self.downloading = YES;
    [self.downloadTask resume];
}

- (BOOL)isDownloading
{
    return self.downloading;
}

- (void)cancelDownload
{
    [self.downloadTask cancel];
    self.downloading = NO;
}




#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    //TODO: implement method to support resume download (for pause or lost connection)
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
        NSURL *documentsDirectory = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        NSURL *originalURL = downloadTask.originalRequest.URL;
        self.destinationURL = [documentsDirectory URLByAppendingPathComponent:originalURL.lastPathComponent];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self.destinationURL path]]) {
        if (self.canReplace) {
            [fileManager removeItemAtURL:self.destinationURL error:NULL];
        } else {
            self.destinationURL = [self.destinationURL URLByUniquingPath];
        }
    }
    BOOL success = [fileManager copyItemAtURL:location toURL:self.destinationURL error:nil];
    Map *newMap = nil;
    if (success) {
        NSURL *savedUrl = self.url;
        newMap = self;  //This is a cheat, I should make a copy, but self (the obsolete remote version) will be removed momentarily
        newMap.url = self.destinationURL;
        if (!newMap.isValid) {
            newMap = nil;
            self.url = savedUrl;
        }
    }
    if (self.downloadCompletionAction){
        self.downloadCompletionAction(newMap);
    }
}

-(NSString *)description
{
    return [NSString stringWithFormat:@"%@ by %@, dated: %@", self.title, self.author, [self.date stringWithMediumDateFormat]];
}

@end
