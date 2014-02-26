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
#import "NSArray+map.h"

#define kCodingVersion    1
#define kCodingVersionKey @"codingversion"
#define kUrlKey           @"url"
#define kPTitleKey         @"title"
#define kVersionKey       @"version"
#define kDateKey          @"date"
#define kJsonDateFormat   @""


@interface SProtocol() {
    NSString *_title;  //properties from a protocol cannot be synthesized
}
@property (nonatomic) BOOL parsedJSON;
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
                               title:[aDecoder decodeObjectForKey:kPTitleKey]
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
    [aCoder encodeObject:_title forKey:kPTitleKey];
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

- (BOOL)isLocal
{
    return self.url.isFileURL;
}

- (BOOL)isValid
{
    return self.features.count > 0 && self.missionFeature != nil;
}

// I do not override isEqual to use this method, because title,version and date could change
// when the values are accessed.  This would cause the hash value to change which can cause
// all kinds of problems if the object is used in a dictionary or set.
- (BOOL)isEqualToProtocol:(SProtocol *)other
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
    //TODO: This check causes remote data to be downloaded and parsed, then we downloaded it again if it is valid
    if (!self.isLocal && self.isValid) {
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
    return [[NSData dataWithContentsOfURL:self.url] writeToURL:url options:0 error:nil];
}


#pragma mark - formatting for UI views

- (NSString *)dateString
{
    return self.date ? [self.date stringWithMediumDateFormat] : @"Unknown";
}

- (NSString *)versionString
{
    return self.version ? [self.version stringValue] : @"Unknown";
}


#pragma mark - property accessors

@synthesize details = _details;

- (NSString *)details
{
    if (!self.parsedJSON) {
        [self parseJSON];
    }
    return _details;
}

@synthesize features = _features;

- (NSArray *)features
{
    if (!self.parsedJSON) {
        [self parseJSON];
    }
    return _features;
}

@synthesize missionFeature = _missionFeature;

- (ProtocolMissionFeature *)missionFeature
{
    if (!self.parsedJSON) {
        [self parseJSON];
    }
    return _missionFeature;
}

@synthesize featuresWithLocateByTouch = _featuresWithLocateByTouch;

- (NSArray *) featuresWithLocateByTouch
{
    if (!self.parsedJSON) {
        [self parseJSON];
    }
    return _featuresWithLocateByTouch;
}

-(NSString *)description
{
    return [NSString stringWithFormat:@"%@; %@",self.title, self.subtitle];
}



#pragma mark - JSON parsing

- (void)parseJSON
{
    self.parsedJSON = YES;
    NSData *data = [NSData dataWithContentsOfURL:self.url];
    if (data) {
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([json isKindOfClass:[NSDictionary class]])
        {
            if ([@"NPS-Protocol-Specification" isEqual:json[@"meta-name"]]) {
                id item = json[@"meta-version"];
                if ([item isKindOfClass:[NSNumber class]]) {
                    NSInteger version = [(NSNumber *)item integerValue];
                    switch (version) {
                        case 1:
                            [self processProtocolJSON:json version:version];
                            break;
                        default:
                            AKRLog(@"Unsupported version (%d) of the NPS-Protocol-Specification", version);
                            break;
                    }
                }
            }
        }
    }
}

- (void)processProtocolJSON:(NSDictionary *)json version:(NSInteger)jsonVersion
{
    id title = json[@"name"];
    _title = ([title isKindOfClass:[NSString class]] ? title : nil);

    id version =  json[@"version"];
    _version = ([version isKindOfClass:[NSNumber class]] ? version : nil);

    id date = json[@"date"];
    _date = [AKRFormatter dateFromISOString:([date isKindOfClass:[NSString class]] ? date : nil)];

    id details = json[@"description"];
    _details = [details isKindOfClass:[NSString class]] ? details : @"";

    _missionFeature = [[ProtocolMissionFeature alloc] initWithJSON:json[@"mission"] version:jsonVersion];
    _features = [self buildFeaturelist:json[@"features"] version:jsonVersion];
    _featuresWithLocateByTouch = [self buildFeaturesWithLocateByTouch:_features];
}

- (NSArray *)buildFeaturelist:(id)json version:(NSInteger) version
{
    NSMutableArray *features = [[NSMutableArray alloc] init];
    if ([json isKindOfClass:[NSArray class]]) {
        for (id item in json) {
            ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:item version:version];
            if (feature) {
                [features addObject:feature];
            }
        }
    }
    return [features copy];
}

- (NSArray *)buildFeaturesWithLocateByTouch:(NSArray *)features
{
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    for (ProtocolFeature *feature in features) {
        if (feature.allowedLocations.countOfTouchChoices > 0) {
            [newArray addObject:feature];
        }
    }
    return [newArray copy];
}

@end
