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
@property (nonatomic, readwrite) CGRect extents;

@property (nonatomic) BOOL downloading;
@property (nonatomic, strong, readwrite) UIImage *thumbnail;
@property (nonatomic, strong, readwrite) id tileCache;
@property (nonatomic, strong) NSURL *thumbnailUrl;
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
        map.extents = CGRectMake(xmin, ymin, xmax - xmin, ymax - ymin);
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
                map.extents = [[aDecoder decodeObjectForKey:kExtentsKey] CGRectValue];
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
    [aCoder encodeObject:[NSValue valueWithCGRect:_extents] forKey:kExtentsKey];
}

#pragma mark - Lazy property initiallizers



#pragma mark - FSTableViewItem

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

- (id)tileCache
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


#pragma mark - date formatters

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

- (NSString *)details
{
    return @"get details from the tilecache";
}

- (NSString *)byteSizeString
{
    if (self.byteCount == 0) {
        return @"Unknown";
    } else if (self.byteCount < 1024) {
        return [NSString stringWithFormat:@"%d Bytes", self.byteCount];
    } else if (self.byteCount < 1024*1024) {
        return [NSString stringWithFormat:@"%d KB", self.byteCount / 1024];
    } else if (self.byteCount < 1024*1024*1024) {
        return [NSString stringWithFormat:@"%d MB", self.byteCount / 1024 / 1024];
    } else {
        return [NSString stringWithFormat:@"%0.2f GB", self.byteCount / 1024.0 / 1024 / 1024];
    }
}

- (NSString *)arealSizeString
{
    if (self.extents.size.height == 0 || self.extents.size.width == 0) {
        return @"Unknown";
    }
    double midLatitude = self.extents.origin.y + self.extents.size.height / 2;
    double widthScale = cos(midLatitude * M_PI / 180.0);
    double radius = 6371.0;
    double circumfrence = M_PI * 2 * radius;
    double width = circumfrence * self.extents.size.width / 360 * widthScale;
    double height = circumfrence * self.extents.size.height / 360;
    double areakm = height * width;
    double areami = areakm * 1200/3937 *1200/3937;
    NSString *format = areami < 100 ? @"%0.2f sq. mi (%0.2f sq km)" : @"%0.0f sq. mi (%0.0f sq km)";
    return [NSString stringWithFormat:format, areami, areakm];
}



- (BOOL)loadThumbnail
{
    self.thumbnailIsLoaded = YES;
    //_thumbnail = [[UIImage alloc] initWithContentsOfFile:[self.thumbnailUrl path]];
    _thumbnail = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:self.thumbnailUrl]];
    if (!_thumbnail)
        _thumbnail = [UIImage imageNamed:@"TilePackage"];
    return !_thumbnail;
}

- (BOOL)loadTileCache
{
    self.tileCacheIsLoaded = YES;
    _tileCache = nil; //FIXME: Get tilecache when linked to ArcGIS
    return !_tileCache;
}

@end
