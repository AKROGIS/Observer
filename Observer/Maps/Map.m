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

//#define kCodingVersion    1
//#define kCodingVersionKey @"codingversion"
//#define kExtentsKey       @"extents"

@interface Map()

//A private dictionary of map properties
@property (nonatomic, strong) NSDictionary *properties;

//This will change when a map is downloaded
@property (nonatomic, strong, readwrite) NSURL *tileCacheURL;

//Loading resources
@property (nonatomic,         readwrite) BOOL isThumbnailLoaded;
@property (nonatomic,         readwrite) BOOL isTileCacheLoaded;
@property (nonatomic, strong, readwrite) UIImage *thumbnail;
@property (nonatomic, strong, readwrite) AGSLocalTiledLayer *tileCache;

//TODO: move to NSOperation
@property (nonatomic) BOOL isDownloading;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionTask *downloadTask;

@end

@implementation Map

- (id)initWithProperties:(NSDictionary *)properties
{
    if (!properties) {
        return nil;
    }
    if (self = [super init]) {
        _properties = properties;
    }
    return self;
}

- (id)initWithCachedPropertiesURL:(NSURL *)url
{
    if (!url) {
        return nil;
    }

    if (self = [self initWithProperties:[NSDictionary dictionaryWithContentsOfURL:url]]) {
         _plistURL = url;
    }
    return self;
}

- (id)initWithRemoteProperties:(NSDictionary *)properties
{
    NSMutableDictionary *newProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
    newProperties[kCachedThumbUrlKey] = [Map generateThumbnailURL].absoluteString;
    if (self = [self initWithProperties:[newProperties copy]]) {
        _plistURL = [Map generatePlistURL];
        [newProperties writeToURL:_plistURL atomically:YES];
    }
    return self;
}

- (id)initWithTileCacheURL:(NSURL *)url
{
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil];
    if (!fileAttributes) {
        return nil;
    }
    AGSLocalTiledLayer *tileCache =[Map loadTileCacheAtURL:url];
    if (!tileCache) {
        return nil;
    }
    //create a properties dictionary based on solely on the tilecache contents
    NSMutableDictionary *newProperties = [NSMutableDictionary new];
    newProperties[kTitleKey] = [[url lastPathComponent] stringByDeletingPathExtension];
    newProperties[kAuthorKey] = @"Unknown";
    newProperties[kDateKey] = [fileAttributes fileCreationDate];  //TODO: Get the date from the esriinfo.xml file in the zipped tpk
    newProperties[kSizeKey] = [NSNumber numberWithUnsignedLongLong:[fileAttributes fileSize]];
    newProperties[kUrlKey] = url.absoluteString;
    //kRemoteThumbUrlKey - not available or required
    newProperties[kCachedThumbUrlKey] = [Map generateThumbnailURL].absoluteString;
    newProperties[kDescriptionKey] = @"Not available."; //TODO: get the description from the esriinfo.xml file in the zipped tpk
    newProperties[kXminKey] = [NSNumber numberWithDouble:tileCache.fullEnvelope.xmin];
    newProperties[kYminKey] = [NSNumber numberWithDouble:tileCache.fullEnvelope.ymin];
    newProperties[kXmaxKey] = [NSNumber numberWithDouble:tileCache.fullEnvelope.xmax];
    newProperties[kYmaxKey] = [NSNumber numberWithDouble:tileCache.fullEnvelope.ymax];

    if (self = [self initWithProperties:[newProperties copy]]) {
        _tileCache = tileCache;
        self.isTileCacheLoaded = YES;
        _thumbnail = tileCache.thumbnail;
        self.isThumbnailLoaded = YES;
        [Map saveImage:_thumbnail toURL:self.cachedThumbnailURL];
        _plistURL = [Map generatePlistURL];
        [newProperties writeToURL:_plistURL atomically:YES];
    }
    return self;
}

- (id)initWithTileCacheURL:(NSURL *)url name:(NSString *)name author:(NSString *)author date:(NSDate *)date description:(NSString *)description
{
    if (self = [self initWithTileCacheURL:url]) {
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

+ (NSURL *)generatePlistURL
{
    NSURL *library = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *folder = [library URLByAppendingPathComponent:@"Map Properties" isDirectory:YES];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[folder path]]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [[folder URLByAppendingPathComponent:@"map.plist"] URLByUniquingPath];
}

+ (NSURL *)generateThumbnailURL
{
    NSURL *library = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
    //remove the old folder
    NSURL *oldFolder = [library URLByAppendingPathComponent:@"mapthumbs" isDirectory:YES];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[oldFolder path]]) {
        [[NSFileManager defaultManager] removeItemAtURL:oldFolder error:nil];
    }
    //create the new folder
    NSURL *folder = [library URLByAppendingPathComponent:@"Map Thumbnails" isDirectory:YES];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[folder path]]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [[folder URLByAppendingPathComponent:@"thumbnail.png"] URLByUniquingPath];
}





//- (void)setMapPropertiesFromTpk:(Map *)map
//{
//    NSMutableDictionary *properties = [NSMutableDictionary new];
//    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[map.url path] error:nil];
//    map.thumbnail = map.tileCache.thumbnail;
//    map.thumbnailIsLoaded = YES;
//
//    map.author = @"Unknown"; //TODO: get the author from the esriinfo.xml file in the zipped tpk
//    map.byteCount = [fileAttributes fileSize];
//    map.date = [fileAttributes fileCreationDate];  //TODO: Get the date from the esriinfo.xml file in the zipped tpk
//    map.description = @"Not available."; //TODO: get the description from the esriinfo.xml file in the zipped tpk
//    map.thumbnail = map.tileCache.thumbnail;
//    map.thumbnailIsLoaded = YES;
//    map.extents = map.tileCache.fullEnvelope;
//
//    properties[kDateKey] = [fileAttributes fileCreationDate];  //TODO: Get the date from the esriinfo.xml file in the zipped tpk
//    properties[kAuthorKey] = @"Unknown"; //TODO: get the author from the esriinfo.xml file in the zipped tpk
//    properties[kSizeKey] = [NSNumber numberWithUnsignedLongLong:[fileAttributes fileSize]];
//    properties[kDescriptionKey] = @"Not available."; //TODO: get the description from the esriinfo.xml file in the zipped tpk
//properties[kRemoteThumbnailUrlKey] = map.tileCache.thumbnail;
//properties[kXminKey] = map.tileCache.fullEnvelope.xmin;
//properties[kYminKey] = self.tileCache.fullEnvelope.ymin;
//properties[kXmaxKey] = self.tileCache.fullEnvelope.xmax;
//    properties[kYmaxKey] = self.tileCache.fullEnvelope.ymax;
//
//    self.author = ([item isKindOfClass:[NSString class]] ? item : nil);
//    item =  properties[kSizeKey];
//    self.byteCount = [item isKindOfClass:[NSNumber class]] ? [item unsignedLongLongValue] : 0;
//    item =  properties[kDescriptionKey];
//    self.description = [item isKindOfClass:[NSString class]] ? item : nil;
//    item =  properties[kRemoteThumbnailUrlKey];
//    self.remoteThumbnailUrl = [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
//    item =  properties[kXminKey];
//    CGFloat xmin = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
//    item =  properties[kYminKey];
//    CGFloat ymin = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
//    item =  properties[kXmaxKey];
//    CGFloat xmax = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
//    item =  properties[kYmaxKey];
//    CGFloat ymax = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
//    if (xmin != 0  || ymin != 0 || xmax != 0 || ymax != 0 ) {
//        self.extents = [[AGSEnvelope alloc] initWithXmin:xmin ymin:ymin xmax:xmax ymax:ymax spatialReference:[AGSSpatialReference wgs84SpatialReference]];
//    }
//}
//
//- (id)initWithDictionary:(NSDictionary *)dictionary
//{
//    id item = dictionary[kUrlKey];
//    NSURL *url;
//    if ([item isKindOfClass:[NSString class]]) {
//        url = [NSURL URLWithString:item];
//    }
//    if (!url) {
//        return nil;
//    }
//    Map *map = [self initWithURL:url];
//    if (map) {
//        map.properties = dictionary;
//    }
//    return map;
//}

//#pragma mark - NSCoding
//
//- (id)initWithCoder:(NSCoder *)aDecoder
//{
//    int version = [aDecoder decodeIntForKey:kCodingVersionKey];
//    switch (version) {
//        case 1: {
//            Map *map = [self initWithURL:[aDecoder decodeObjectForKey:kUrlKey]];
//            if (map) {
//                map.title = [aDecoder decodeObjectForKey:kTitleKey];
//                map.author = [aDecoder decodeObjectForKey:kAuthorKey];
//                map.date = [aDecoder decodeObjectForKey:kDateKey];
//                map.description = [aDecoder decodeObjectForKey:kDescriptionKey];
//                NSNumber *bytes = [aDecoder decodeObjectForKey:kSizeKey];
//                map.byteCount = [bytes unsignedIntegerValue];
//                map.remoteThumbnailUrl = [aDecoder decodeObjectForKey:kRemoteThumbnailUrlKey];
//                map.localThumbnailUrl = [aDecoder decodeObjectForKey:kLocalThumbnailUrlKey];
//                map.extents = [[AGSEnvelope alloc] initWithJSON:[aDecoder decodeObjectForKey:kExtentsKey]];
//            }
//            return map;
//        }
//        default:
//            return nil;
//    }
//}
//
//- (void)encodeWithCoder:(NSCoder *)aCoder
//{
//    [aCoder encodeInt:kCodingVersion forKey:kCodingVersionKey];
//    [aCoder encodeObject:self.url forKey:kUrlKey];
//    [aCoder encodeObject:self.title forKey:kTitleKey];
//    [aCoder encodeObject:self.author forKey:kAuthorKey];
//    [aCoder encodeObject:self.date forKey:kDateKey];
//    [aCoder encodeObject:self.description forKey:kDescriptionKey];
//    [aCoder encodeObject:[NSNumber numberWithUnsignedLongLong:self.byteCount] forKey:kSizeKey];
//    [aCoder encodeObject:self.remoteThumbnailUrl forKey:kRemoteThumbnailUrlKey];
//    [aCoder encodeObject:self.localThumbnailUrl forKey:kLocalThumbnailUrlKey];
//    [aCoder encodeObject:[self.extents encodeToJSON] forKey:kExtentsKey];
//}
//- (void)setProperties:(NSDictionary *)properties
//{
//    id item = properties[kTitleKey];
//    self.title = ([item isKindOfClass:[NSString class]] ? item : nil);
//    item = properties[kDateKey];
//    self.date = [item isKindOfClass:[NSDate class]] ? item : ([item isKindOfClass:[NSString class]] ? [AKRFormatter dateFromISOString:item] : nil);
//    item = properties[kAuthorKey];
//    self.author = ([item isKindOfClass:[NSString class]] ? item : nil);
//    item =  properties[kSizeKey];
//    self.byteCount = [item isKindOfClass:[NSNumber class]] ? [item unsignedLongLongValue] : 0;
//    item =  properties[kDescriptionKey];
//    self.description = [item isKindOfClass:[NSString class]] ? item : nil;
//    item =  properties[kRemoteThumbnailUrlKey];
//    self.remoteThumbnailUrl = [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
//    item =  properties[kXminKey];
//    CGFloat xmin = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
//    item =  properties[kYminKey];
//    CGFloat ymin = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
//    item =  properties[kXmaxKey];
//    CGFloat xmax = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
//    item =  properties[kYmaxKey];
//    CGFloat ymax = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
//    if (xmin != 0  || ymin != 0 || xmax != 0 || ymax != 0 ) {
//        self.extents = [[AGSEnvelope alloc] initWithXmin:xmin ymin:ymin xmax:xmax ymax:ymax spatialReference:[AGSSpatialReference wgs84SpatialReference]];
//    }
//
//    item = properties[kLocalThumbnailUrlKey];
//    if (item) {
//        self.localThumbnailUrl = [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
//    } else {
//        NSMutableDictionary newProps = [NSMutableDictionary dictionaryWithDictionary:properties];
//        newProps[kLocalThumbnailUrlKey] = self.localThumbnailUrl;
//        properties = [newProps copy];
//    }
//
//    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.propertiesCacheUrl path]]) {
//        [properties writeToURL:self.propertiesCacheUrl atomically:YES];
//    }
//}





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

- (NSString *)date
{
    id item = self.properties[kDateKey];
    return [item isKindOfClass:[NSDate class]] ? item : ([item isKindOfClass:[NSString class]] ? [AKRFormatter dateFromISOString:item] : nil);
}

- (unsigned long long)byteCount
{
    id item = self.properties[kSizeKey];
    return [item isKindOfClass:[NSNumber class]] ? [item unsignedLongLongValue] : 0;
}

- (NSURL *)tileCacheURL
{
    id item = self.properties[kUrlKey];
    return [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
}

//Alert: Mutating function
//Alert: will block for IO
- (void)setTileCacheURL:(NSURL *)tileCacheURL
{
    if (![tileCacheURL isEqualToURL:self.tileCacheURL]) {
        NSMutableDictionary *newProperties = [NSMutableDictionary dictionaryWithDictionary:self.properties];
        newProperties[kUrlKey] = tileCacheURL.absoluteString;
        self.properties = [newProperties copy];
        [newProperties writeToURL:self.plistURL atomically:YES];
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
    return [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
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
        CGFloat xmin = [item floatValue];
        item =  self.properties[kYminKey];
        if (![item isKindOfClass:[NSNumber class]]) {
            return nil;
        }
        CGFloat ymin = [item floatValue];
        item =  self.properties[kXmaxKey];
        if (![item isKindOfClass:[NSNumber class]]) {
            return nil;
        }
        CGFloat xmax = [item floatValue];
        item =  self.properties[kYmaxKey];
        if (![item isKindOfClass:[NSNumber class]]) {
            return nil;
        }
        CGFloat ymax = [item floatValue];
        if (xmin != xmax && ymin != ymax) {
            _extents = [[AGSEnvelope alloc] initWithXmin:xmin ymin:ymin xmax:xmax ymax:ymax spatialReference:[AGSSpatialReference wgs84SpatialReference]];
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
        return [NSString stringWithFormat:@"Date: %@, Size: %@", [self.date stringWithMediumDateFormat], [AKRFormatter stringFromBytes:self.byteCount]];
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
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.cachedThumbnailURL.path]) {
        _thumbnail = [Map loadThumbnailAtURL:self.cachedThumbnailURL];
    } else {
        _thumbnail = [Map loadThumbnailAtURL:self.remoteThumbnailURL];
        [Map saveImage:_thumbnail toURL:self.cachedThumbnailURL];
    }
    self.isThumbnailLoaded = YES;
}

//Alert: will block for IO
+ (UIImage *)loadThumbnailAtURL:(NSURL *)url
{
    if (url.isFileURL) {
        return [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:url]];
    } else {
        //TODO: do this transfer in an NSOperation Queue
        //TODO: need to deal with various network errors
        return [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:url]];
    }
}

//Alert: will block for IO
+ (void)saveImage:(UIImage *)image toURL:(NSURL *)url
{
    if (url.isFileURL) {
        [UIImagePNGRepresentation(image) writeToURL:url atomically:YES];
    }
}




#pragma mark - Load TileCache

//Alert: may call a mutating function
//Alert: may block for IO
- (AGSLocalTiledLayer *)tileCache
{
    if (!_tileCache && !self.isTileCacheLoaded) {
        [self loadTileCache];
    }
    return _tileCache;
}

//Alert: will call a mutating function
- (void)loadTileCacheWithCompletionHandler:(void (^)(BOOL success))completionHandler {
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
        [self loadTileCache];
        if (completionHandler) {
            completionHandler(self.tileCache != nil);
        }
    });
}

//Alert: Mutating function
//Alert: will block for IO
- (void)loadTileCache {
    _tileCache = [Map loadTileCacheAtURL:self.tileCacheURL];
    self.isTileCacheLoaded = YES;
}

//Alert: will block for IO
+ (AGSLocalTiledLayer *)loadTileCacheAtURL:(NSURL *)url
{
    //with ArcGIS 10.2 tilecache is non-null even when initilazing with a bad file
    //However accessing properties like fullEnvelope will yield an EXC_BAD_ACCESS if it is invalid
    //We do the sanity check now to avoid any surprises later.
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        AGSLocalTiledLayer *tiles = [[AGSLocalTiledLayer alloc] initWithPath:url.path];
        @try {
            if (tiles.fullEnvelope && !tiles.fullEnvelope.isEmpty) {
                return tiles;
            }
        }
        @catch (NSException *exception) {
            AKRLog(@"Exception %@ when loading tile cache %@",exception,url);
            return nil;
        }
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

//- (BOOL) isValid
//{
//    return !self.isLocal || [[NSFileManager defaultManager] fileExistsAtPath:self.tileCacheURL.path];
//}

- (BOOL)isEqualToRemoteProperties:(NSDictionary *)remoteMapProperties
{
    //Equality is not well defined here, but I am trying to answer this question:
    //Is the tilecache represented by the remote properties the same as a tilecache that I already have already memorized?

    //Metadata equality
    //Equal if the title, author and date are the same. (even if the content (URL/size) maybe different)
    id item = remoteMapProperties[kDateKey];
    NSDate *remoteDate = [item isKindOfClass:[NSDate class]] ? item : ([item isKindOfClass:[NSString class]] ? [AKRFormatter dateFromISOString:item] : nil);
    if (self.title == remoteMapProperties[kTitleKey] && self.author == remoteMapProperties[kAuthorKey] && self.date == remoteDate) {
        return YES;
    }
    //Content equality
    //Equal if the name (last componenet of the URL) and the bytecount are the same. (even if the Title/Author/Date are different)
    item = remoteMapProperties[kSizeKey];
    unsigned long long remoteByteCount = [item isKindOfClass:[NSNumber class]] ? [item unsignedLongLongValue] : 0;
    NSString *thisName = [self.tileCacheURL lastPathComponent];
    item = remoteMapProperties[kUrlKey];
    NSURL *remoteURL = [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
    NSString *remoteName = [remoteURL lastPathComponent];
    if ([thisName isEqualToString:remoteName] && self.byteCount == remoteByteCount) {
        return YES;
    }
    return NO;
}

- (BOOL)shouldUpdateToRemoteProperties:(NSDictionary *)remoteMapProperties
{
    //Any of the properties may have changed. to answer this, I would need to check each property
    //In addition the resource at the end of the thumnail URL may have been updated, and I have no way to determine this
    //Unless this is a problem, I will assume the worst.
    return !self.isLocal;
}

//Alert: Mutating function
//Alert: will block for IO
- (void)updateWithRemoteProperties:(NSDictionary *)remoteMapProperties
{
    if (self.isLocal) {
        return;
    }
    NSMutableDictionary *newProperties = [NSMutableDictionary dictionaryWithDictionary:remoteMapProperties];
    //the cachedThumbnailURL, and the tileCacheURL are the only properties that I might have changed.
    newProperties[kCachedThumbUrlKey] = self.properties[kCachedThumbUrlKey];
    if (self.isLocal) {
        //save the local URL, so we do not revert to a remote tilecache
        newProperties[kUrlKey] = self.properties[kUrlKey];
    }
    //remove cached properties
    [[NSFileManager defaultManager] removeItemAtURL:self.cachedThumbnailURL error:nil];
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
    return [[AGSGeometryEngine defaultGeometryEngine] shapePreservingAreaOfGeometry:self.extents inUnit:AGSAreaUnitsSquareKilometers];
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




//#pragma mark - loaders
//
//
//- (BOOL)hasLoadedThumbnail
//{
//    return self.thumbnailIsLoaded;
//}
//
//- (void)loadThumbnailWithCompletionHandler:(void (^)(BOOL success))completionHandler
//{
//    if (self.thumbnail || self.thumbnailIsLoaded) {
//        if (completionHandler) {
//            completionHandler(self.thumbnail != nil);
//        }
//    }
//    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
//        [self loadThumbnail];
//        if (completionHandler) {
//            completionHandler(self.thumbnail != nil);
//        }
//    });
//}
//
//- (void)setThumbnail:(UIImage *)image
//{
//    if (!self.localThumbnailUrl || ![[NSFileManager defaultManager] fileExistsAtPath:[self.localThumbnailUrl path]]) {
//        NSString *name = [self.url.lastPathComponent stringByDeletingPathExtension];
//        NSURL *cachedImage = [self cacheThumbnail:image mapName:name];
//        self.localThumbnailUrl = cachedImage;
//    }
//    _thumbnail = image;
//}
//
//- (void)loadThumbnail
//{
//    NSData *data = nil;
//    if (self.localThumbnailUrl && [[NSFileManager defaultManager] fileExistsAtPath:[self.localThumbnailUrl path]]) {
//         data = [NSData dataWithContentsOfURL:self.localThumbnailUrl];
//    } else {
//        //TODO: do this transfer in an NSOperation Queue
//        //TODO: need to deal with various network errors
//        data = [NSData dataWithContentsOfURL:self.remoteThumbnailUrl];
//    }
//    if (data) {
//        self.thumbnail = [[UIImage alloc] initWithData:data];
//    }
//    self.thumbnailIsLoaded = YES;
//    //Update the cache:
//    //TODO: Have the map manage it's own cache, so I don't need call the collection to do the save;
//    //[[MapCollection sharedCollection] synchronize];
//}
//
//- (NSURL *)cacheThumbnail:(UIImage *)image mapName:(NSString *)name
//{
//    //save the image in a cache folder and return the URL
//    //Use the name to index and name the image.
//    // If there is no cached image with given name, then create it and be done.
//    // If the name exists, and the data is the same, then return the existing URL
//    // If the name exists, and the data is NOT the same, then uniquify the URL and save the image
//
//    NSURL *library = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
//    NSURL *folder = [library URLByAppendingPathComponent:@"mapthumbs" isDirectory:YES];
//    if (![[NSFileManager defaultManager] fileExistsAtPath:[folder path]]) {
//        [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
//    }
//    NSURL *thumb = [[folder URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"png"];
//    if ([[NSFileManager defaultManager] fileExistsAtPath:[thumb path]]) {
//        if ([UIImagePNGRepresentation(image) isEqualToData:[NSData dataWithContentsOfURL:thumb]]) {
//            //FIXME: this equality doesn't work remote thumbnail <> tpk thumbnail
//            return thumb;
//        } else {
//            thumb = [thumb URLByUniquingPath];
//        }
//    }
//    [UIImagePNGRepresentation(image) writeToURL:thumb atomically:YES];
//    return thumb;
//}
//
//- (NSURL *)cacheProperties:(NSDictionary *)properties mapName:(NSString *)name
//{
//    //save the image in a cache folder and return the URL
//    //Use the name to index and name the image.
//    // If there is no cached image with given name, then create it and be done.
//    // If the name exists, and the data is the same, then return the existing URL
//    // If the name exists, and the data is NOT the same, then uniquify the URL and save the image
//
//    NSURL *library = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
//    NSURL *folder = [library URLByAppendingPathComponent:@"mapprops" isDirectory:YES];
//    if (![[NSFileManager defaultManager] fileExistsAtPath:[folder path]]) {
//        [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
//    }
//    NSURL *thumb = [[folder URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"png"];
//    if ([[NSFileManager defaultManager] fileExistsAtPath:[thumb path]]) {
//        if ([UIImagePNGRepresentation(image) isEqualToData:[NSData dataWithContentsOfURL:thumb]]) {
//            //FIXME: this equality doesn't work remote thumbnail <> tpk thumbnail
//            return thumb;
//        } else {
//            thumb = [thumb URLByUniquingPath];
//        }
//    }
//    [UIImagePNGRepresentation(image) writeToURL:thumb atomically:YES];
//    return thumb;
//}




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
    NSURLRequest *request = [NSURLRequest requestWithURL:self.tileCacheURL];
    self.downloadTask = [self.session downloadTaskWithRequest:request];
    self.downloadPercentComplete = 0;
    self.isDownloading = YES;
    [self.downloadTask resume];
    [MapCollection startDownloading];
}

- (void)cancelDownload
{
    [self.downloadTask cancel];
    self.isDownloading = NO;
    [MapCollection canceledDownloading];
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
    self.isDownloading = NO;
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
//    Map *newMap = nil;
//    if (success) {
//        NSURL *savedUrl = self.url;
//        newMap = self;  //This is a cheat, I should make a copy, but self (the obsolete remote version) will be removed momentarily
//        newMap.url = self.destinationURL;
//        if (!newMap.isValid) {
//            newMap = nil;
//            self.url = savedUrl;
//        }
//    }
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
    return [NSString stringWithFormat:@"%@ by %@, dated: %@", self.title, self.author, [self.date stringWithMediumDateFormat]];
}

@end
