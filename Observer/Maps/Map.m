//
//  Map.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

//TODO: implement download, and update progress view.
//TODO: cache the thumbnail, change the thumbnail (then need to resave cache)
//TODO: format properties for the details view (add outlets in the details VC
//TODO: implement distance to map and map area
//TODO: get map properties from the tilecache if we got it from the document directory, email, or web page.
//TODO: Allow editing of the map name.

#import "Map.h"
#import "NSDate+Formatting.h"
#import "NSURL+unique.h"

#define kCodingVersion    1
#define kCodingVersionKey @"codingversion"
#define kUrlKey           @"url"
#define kThumbnailUrlKey  @"thumbnail"
#define kTitleKey         @"name"
#define kAuthorKey        @"author"
#define kDateKey          @"date"
#define kDescriptionKey   @"description"
#define kSizeKey          @"size"
#define kExtentsKey       @"extents"

@interface Map()

@property (nonatomic, strong, readwrite) NSString *title;
@property (nonatomic, strong, readwrite) NSString *description;
@property (nonatomic, strong, readwrite) NSString *author;
@property (nonatomic, strong, readwrite) NSDate *date;
@property (nonatomic, readwrite) NSUInteger byteCount;
@property (nonatomic, readwrite) AGSEnvelope *extents;

@property (nonatomic) BOOL downloading;
@property (nonatomic, strong, readwrite) UIImage *thumbnail;
@property (nonatomic, strong, readwrite) AGSLocalTiledLayer *tileCache;
@property (nonatomic, strong, readwrite) NSURL *thumbnailUrl;
@property (nonatomic) BOOL thumbnailIsLoaded;
@property (nonatomic) BOOL tileCacheIsLoaded;

@end

@implementation Map

- (id) initWithURL:(NSURL *)url
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
        map.thumbnailUrl = [self thumbnailUrlForMapName:map.title];
        [UIImagePNGRepresentation(map.tileCache.thumbnail) writeToURL:map.thumbnailUrl atomically:YES];
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
        map.date = [item isKindOfClass:[NSDate class]] ? item : ([item isKindOfClass:[NSString class]] ? [self dateFromString:item] : nil);
        item = dictionary[kAuthorKey];
        map.author = ([item isKindOfClass:[NSString class]] ? item : nil);
        item =  dictionary[kSizeKey];
        map.byteCount = [item isKindOfClass:[NSNumber class]] ? [item integerValue] : 0;
        item =  dictionary[kDescriptionKey];
        map.description = [item isKindOfClass:[NSString class]] ? item : nil;
        item =  dictionary[kThumbnailUrlKey];
        map.thumbnailUrl = [item isKindOfClass:[NSString class]] ? [NSURL URLWithString:item] : nil;
        item =  dictionary[@"xmin"];
        CGFloat xmin = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
        item =  dictionary[@"ymin"];
        CGFloat ymin = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
        item =  dictionary[@"xmax"];
        CGFloat xmax = [item isKindOfClass:[NSNumber class]] ? [item floatValue] : 0.0;
        item =  dictionary[@"ymax"];
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
                map.byteCount = [aDecoder decodeIntegerForKey:kSizeKey];
                map.thumbnailUrl = [aDecoder decodeObjectForKey:kThumbnailUrlKey];
                map.extents = [[AGSEnvelope alloc] initWithJSON:[aDecoder decodeObjectForKey:kExtentsKey]];
            }
            return map;
        }
        default:
            return nil;
    }
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt:kCodingVersion forKey:kCodingVersionKey];
    [aCoder encodeObject:_url forKey:kUrlKey];
    [aCoder encodeObject:_title forKey:kTitleKey];
    [aCoder encodeObject:_author forKey:kAuthorKey];
    [aCoder encodeObject:_date forKey:kDateKey];
    [aCoder encodeObject:_description forKey:kDescriptionKey];
    [aCoder encodeInteger:_byteCount forKey:kSizeKey];
    [aCoder encodeObject:_thumbnailUrl forKey:kThumbnailUrlKey];
    [aCoder encodeObject:[_extents encodeToJSON] forKey:kExtentsKey];
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
    if (self.downloading) {
        return @"Downloading...";
    } else {
        return [NSString stringWithFormat:@"Author: %@, Date: %@", self.author, [self.date stringWithMediumDateFormat]];
    }
}

- (NSString *)subtitle2
{
    if (self.downloading) {
        return @"Downloading...";
    } else {
        return [NSString stringWithFormat:@"Size: %@", (self.isLocal ? self.arealSizeString : self.byteSizeString)];
    }
}

- (UIImage *)thumbnail
{
    if (!_thumbnail && !self.thumbnailIsLoaded) {
        [self loadThumbnail];
    }
    return _thumbnail;
}

- (AGSLocalTiledLayer *)tileCache
{
    if (!_tileCache && !self.tileCacheIsLoaded) {
        [self loadTileCache];
    }
    return _tileCache;
}


#pragma mark - public methods

- (BOOL)isLocal
{
    return self.url.isFileURL;
}

// I do not override isEqual to use this method, because title,version and date could change
// when the values are accessed.  This would cause the hash value to change which can cause
// all kinds of problems if the object is used in a dictionary or set.
- (BOOL)isEqualtoMap:(Map *)other
{
    // need to be careful with null properties.
    // without the == check, two null properties will be not equal
    return
    (self.byteCount == other.byteCount) &&
    ((self.author == other.author) || [self.author isEqual:other.author]) &&
    ((self.date == other.date) || [self.date isEqual:other.date]);
}

- (void)prepareToDownload
{
    self.downloading = YES;
}

- (BOOL)isDownloading
{
    return self.downloading;
}


- (BOOL)downloadToURL:(NSURL *)url
{
    //FIXME: use NSURLSession, and use delegate to provide progress indication
    BOOL success = NO;
    if (!self.isLocal && self.tileCache) {
        if ([self saveCopyToURL:url]) {
            _url = url;
            success = YES;
        } else {
            NSLog(@"Map.downloadToURL:  Got data but write to %@ failed",url);
        }
    } else {
        NSLog(@"Map.downloadToURL: Unable to get data at %@", self.url);
    }
    self.downloading = NO;
    return success;
}

- (BOOL)saveCopyToURL:(NSURL *)url
{
    NSOutputStream *stream = [NSOutputStream outputStreamWithURL:url append:NO];
    [stream open];
    NSInteger numberOfBytesWritten = 0; //FIXME: get tilecache at remote URL and write to stream
    [stream close];
    return numberOfBytesWritten > 0;
}


- (BOOL)loadThumbnail
{
    self.thumbnailIsLoaded = YES;
    //TODO: if thumbnailUrl is not local, then download it, cache it, and update the url, let collection know the cache needs to be updated.

    //_thumbnail = [[UIImage alloc] initWithContentsOfFile:[self.thumbnailUrl path]];
    _thumbnail = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:self.thumbnailUrl]];
    if (!_thumbnail)
        _thumbnail = [UIImage imageNamed:@"TilePackage"];
    return !_thumbnail;
}

- (NSURL *)thumbnailUrlForMapName:(NSString *)name
{
    NSURL *library = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask][0];
    NSURL *folder = [library URLByAppendingPathComponent:@"mapthumbs" isDirectory:YES];
    if (![[NSFileManager defaultManager] fileExistsAtPath:[folder path]]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSURL *thumb = [[[folder URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"png"] URLByUniquingPath];
    return thumb;
}


- (NSString *)details
{
    return @"get details from the tilecache";
}


#pragma mark - formatters

//cached date formatters per xcdoc://ios/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html
- (NSDate *) dateFromString:(NSString *)date
{
    if (!date) {
        return nil;
    }
    static NSDateFormatter *dateFormatter = nil;
    if (!dateFormatter) {
        dateFormatter = [NSDateFormatter new];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd"];
        [dateFormatter setLenient:YES];
    }
    return [dateFormatter dateFromString:date];
}

+ (NSString *)formatBytes:(long long)bytes
{
    static NSByteCountFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSByteCountFormatter new];
    });
    return [formatter stringFromByteCount:bytes];
}

+ (NSString *)formatArea:(double)area
{
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.maximumSignificantDigits = 3;
    });
    return [formatter stringFromNumber:[NSNumber numberWithDouble:area]];
}

- (NSString *)byteSizeString
{
    return [Map formatBytes:self.byteCount];
}

#pragma mark - tilecache (ESRI functionality)

- (BOOL)loadTileCache
{
    self.tileCacheIsLoaded = YES;
    _tileCache = [[AGSLocalTiledLayer alloc] initWithPath:[self.url path]];
    return _tileCache != nil;
}

- (NSString *)arealSizeString
{
    if (!self.extents || self.extents.isEmpty) {
        return @"Unknown";
    }

    double areakm = [[AGSGeometryEngine defaultGeometryEngine] shapePreservingAreaOfGeometry:self.extents inUnit:AGSAreaUnitsSquareKilometers];
    //TODO: query settings for a metric/SI preference
    if (YES) {
        return [NSString stringWithFormat:@"%@ sq km", [Map formatArea:areakm]];
    } else {
        double areami = areakm * 0.386102;
        return [NSString stringWithFormat:@"%@ sq mi", [Map formatArea:areami]];
    }
}


- (AKRAngleDistance *)angleDistanceFromLocation:(CLLocation *)location
{
    return [AKRAngleDistance angleDistanceFromLocation:location toGeometry:self.extents];
}

@end
