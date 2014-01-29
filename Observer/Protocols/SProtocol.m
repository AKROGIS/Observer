//
//  Protocol.m
//  Observer
//
//  Created by Regan Sarwas on 11/18/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SProtocol.h"
#import "AKRFormatter.h"
#import "NSDate+Formatting.h"

#define kCodingVersion    1
#define kCodingVersionKey @"codingversion"
#define kUrlKey           @"url"
#define kTitleKey         @"title"
#define kVersionKey       @"version"
#define kDateKey          @"date"
#define kJsonDateFormat   @""


@interface SProtocol() {
    NSString *_title;  //properties from an implemented cannot be synthesized
}
@property (nonatomic) BOOL downloading;
@end

@implementation SProtocol


- (id) initWithURL:(NSURL *)url title:(id)title version:(id)version date:(id)date
{
    if (!url) {
        return nil;
    }
    if (self = [super init]) {
        _url = url;
        _title = ([title isKindOfClass:[NSString class]] ? title : nil);
        _version = ([version isKindOfClass:[NSNumber class]] ? version : nil);
        _date = [date isKindOfClass:[NSDate class]] ? date : ([date isKindOfClass:[NSString class]] ? [AKRFormatter dateFromISOString:date] : nil);
    }
    return self;
}


- (id) initWithURL:(NSURL *)url
{
    return [self initWithURL:url
                       title:url.lastPathComponent
                     version:nil
                        date:nil];
}


#pragma mark - Lazy property initiallizers

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    int version = [aDecoder decodeIntForKey:kCodingVersionKey];
    switch (version) {
        case 1:
            return [self initWithURL:[aDecoder decodeObjectForKey:kUrlKey]
                               title:[aDecoder decodeObjectForKey:kTitleKey]
                             version:[aDecoder decodeObjectForKey:kVersionKey]
                                date:[aDecoder decodeObjectForKey:kDateKey]];
        default:
            return nil;
    }
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt:kCodingVersion forKey:kCodingVersionKey];
    [aCoder encodeObject:_url forKey:kUrlKey];
    [aCoder encodeObject:_title forKey:kTitleKey];
    [aCoder encodeObject:_version forKey:kVersionKey];
    [aCoder encodeObject:_date forKey:kDateKey];
}


#pragma mark - AKRTableViewItem

- (NSString *)title
{
    return _title ? _title : @"No Title";
}

- (NSString *)subtitle
{
    if (self.downloading) {
        return @"Downloading...";
    } else {
        return [NSString stringWithFormat:@"Version: %@, Date: %@", self.versionString, self.dateString];
    }
}

- (UIImage *)thumbnail
{
    return nil;
}


#pragma mark - public methods

@synthesize values = _values;  //need to synthesize because I am implementing all property methods

- (NSDictionary *)values
{
    if (!_values) {
        NSData *data = [NSData dataWithContentsOfURL:self.url];
        if (data) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]])
            {
                _values = json;
                id title = _values[@"name"];
                id version =  _values[@"version"];
                id date = _values[@"date"];
                _title = ([title isKindOfClass:[NSString class]] ? title : nil);
                _version = ([version isKindOfClass:[NSNumber class]] ? version : nil);
                _date = [AKRFormatter dateFromISOString:([date isKindOfClass:[NSString class]] ? date : nil)];
            }
        }
    }
    return _values;
}

- (BOOL)isLocal
{
    return self.url.isFileURL;
}

// I do not override isEqual to use this method, because title,version and date could change
// when the values are accessed.  This would cause the hash value to change which can cause
// all kinds of problems if the object is used in a dictionary or set.
- (BOOL)isEqualtoProtocol:(SProtocol *)other
{
    // need to be careful with null properties.
    // without the == check, two null properties will be not equal
    return ((self.title == other.title) || [self.title isEqualToString:other.title]) &&
           ((self.version == other.version) || [self.version isEqual:other.version]) &&
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
    BOOL success = NO;
    if (!self.isLocal && self.values) {
        if ([self saveCopyToURL:url]) {
            _url = url;
            success = YES;
        } else {
            AKRLog(@"Protocol.downloadToURL:  Got data but write to %@ failed",url);
        }
    } else {
        AKRLog(@"Protocol.downloadToURL: Unable to get data at %@", self.url);
    }
    self.downloading = NO;
    return success;
}

- (BOOL)saveCopyToURL:(NSURL *)url
{
    NSOutputStream *stream = [NSOutputStream outputStreamWithURL:url append:NO];
    [stream open];
    NSInteger numberOfBytesWritten =  [NSJSONSerialization writeJSONObject:self.values toStream:stream options:NSJSONWritingPrettyPrinted error:nil];
    [stream close];
    return numberOfBytesWritten > 0;
}


#pragma mark - formatting for UI views


- (NSString *)details
{
    id d = self.values[@"description"];
    if ([d isKindOfClass:[NSString class]]) {
        return d;
    } else {
        return @"";
    }
}

- (NSString *)dateString
{
    return self.date ? [self.date stringWithMediumDateFormat] : @"Unknown";
}

- (NSString *)versionString
{
    return self.version ? [self.version stringValue] : @"Unknown";
}


#pragma mark - convenience methods for protocol values

- (NSArray *)features
{
    NSMutableArray *results = [NSMutableArray new];
    id jsonObj = self.values[@"features"];
    if ([jsonObj isKindOfClass:[NSArray class]]) {
        NSArray *entities = (NSArray *)jsonObj;
        for (id jsonEntity in entities) {
            if ([jsonEntity isKindOfClass:[NSDictionary class]]) {
                NSDictionary *entity = (NSDictionary *)jsonEntity;
                if ([entity[@"name"] isKindOfClass:[NSString class]] &&
                    [entity[@"attributes"] isKindOfClass:[NSArray class]]) {
                    [results addObject:entity];
                }
            }
        }
    }
    return results;
}

- (NSDictionary *)dialogs
{
    id jsonObj = self.values[@"dialogs"];
    if ([jsonObj isKindOfClass:[NSDictionary class]]) {
        return jsonObj;
    }
    return nil;
}


-(NSString *)description
{
    return [NSString stringWithFormat:@"%@; %@",self.title, self.subtitle];
}

@end
