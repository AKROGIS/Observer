//
//  BaseMap.m
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "BaseMap.h"
#import "BaseMapManager.h"

@interface BaseMap()

@end

@implementation BaseMap

#pragma mark - initializers

- (id) initWithLocalURL:(NSURL *)localURL andServerURL:(NSURL *)serverUrl
{
    self = [super init];
    if (self) {
        if (!localURL && !serverUrl)
            return nil;
        self.localURL = localURL;
        self.serverURL = serverUrl;
    }
    return self;
}

- (id) initWithLocalURL:(NSURL *)localURL
{
    return [self initWithLocalURL:localURL andServerURL:nil];
}

- (id) initWithServerURL:(NSURL *)serverUrl
{
    return [self initWithLocalURL:nil andServerURL:serverUrl];
}

- (id) init
{
    return [self initWithLocalURL:nil andServerURL:nil];
}

#pragma mark MapManager (or self) managed properties

- (AGSLocalTiledLayer *) tileCache
{
    if (!_tileCache && self.localURL && self.status == MapStatusNormal) {
        _tileCache = [AGSLocalTiledLayer localTiledLayerWithName:[self.localURL absoluteString]];
        if (_tileCache)
            self.status = MapStatusLoadFailed;
    }
    return _tileCache;
}

#pragma mark public properties

- (NSString *) name {
    if (!_name) _name = [self.localURL path];
    return _name;
}

- (NSString *) summary {
    if (!_summary) _summary = self.localURL.absoluteString;
    return _summary;
}


#pragma mark public instance methods

- (BOOL) isOutdated {
    if (!self.serverURL)
        return NO;
    
    NSArray *serverMaps = [[BaseMapManager sharedManager] getServerMaps]; //of BaseMap
    if (!serverMaps)
        return NO;
    
    for (BaseMap *map in serverMaps) {
        if ([map.serverURL isEqual:self.serverURL]) {
            return map.fileDate < map.serverDate;
        }
    }
    return NO;
}

- (BOOL) isOrphan {
    if (!self.serverURL)
        return NO;
    
    NSArray *serverMaps = [[BaseMapManager sharedManager] getServerMaps]; //of BaseMap
    if (!serverMaps)
        return NO;
    
    for (BaseMap *map in serverMaps) {
        if ([map.serverURL isEqual:self.serverURL]) {
            return NO;
        }
    }
    return YES;
}

- (void) download {
#warning incomplete implementation
    //We need to ask the MapManager to do the download, since it knows how to talk to the servers
    if ([self.delegate respondsToSelector:@selector(mapDidFinishDownload:)]) {
        [self.delegate mapDidFinishDownload:self];
    }  
}

- (void) unload {
    #warning check if the file is currentmap
    #warning we should do something if the file does not delete 
    //delete the file
    if ([[NSFileManager defaultManager] removeItemAtURL:self.localURL error:nil])
        self.status = MapStatusLoadFailed;
}


#pragma mark public class methods

+ (BaseMap *) randomMap {
    int i = 1 + rand() % 999;
    NSURL *serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://myserver/mymaps/map%u.tpk", i]];
    BaseMap *map = [[BaseMap alloc] initWithServerURL:serverURL];
    if (map) {
        map.name = [NSString stringWithFormat:@"Map # %u", i];
        map.summary = [serverURL description];
    }
    return map;
}

#pragma mark private methods



@end
