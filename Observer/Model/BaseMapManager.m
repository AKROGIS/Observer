//
//  BaseMapManager.m
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "BaseMapManager.h"

#define DEFAULTS_KEY_CURRENT_MAP_URL @"CurrentMapURL"
#define DEFAULTS_KEY_LOCAL_MAP_URLS @"LocalMapURLs"
#define TILE_CACHE_EXTENSION @"tpk"


@interface BaseMapManager()

@property (strong, nonatomic) NSMutableArray *maps;
@property (strong, nonatomic) NSArray *cachedServerResponse; //of BaseMap

@end

@implementation BaseMapManager


#pragma mark - private ivars and class vars

static BaseMapManager * _sharedManager;


#pragma mark - Public Properties

@synthesize currentMap = _currentMap; //required since I'm implementing a setter and getter

- (BaseMap *)currentMap
{
    if (!_currentMap)
    {
        // Get the current map from defaults
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSURL *currentMapURL = [defaults URLForKey:DEFAULTS_KEY_CURRENT_MAP_URL];
        for (BaseMap *map in self.maps)
        {
            if ([map.localURL isEqual:currentMapURL])
            {
                _currentMap = map;
                break;
            }
        }
    }
    return _currentMap;
}

- (void) setCurrentMap:(BaseMap *)currentMap
{
    if (_currentMap == currentMap)
        return;
    //allow setting the current map to nothing (usually when the current map is deleted)
    if (!currentMap || [self.maps containsObject:currentMap])
    {
        _currentMap = currentMap;
        [self updateNSDefaults];
    }
}

- (NSUInteger) count
{
    return [self.maps count];
}


#pragma mark - Private Properties

//lazy instantiation
- (NSMutableArray *)maps {
    if (!_maps) {
        _maps = [[NSMutableArray alloc] init];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *localMapURLs = [defaults valueForKey:DEFAULTS_KEY_LOCAL_MAP_URLS];
        NSMutableSet *files = [NSMutableSet setWithArray:[self mapURLsInFileManager]];
        // create maps in order from urls saved in defaults  IFF they are found in filesystem
        for (NSString *urlString in localMapURLs) {
            NSURL *url = [NSURL URLWithString:urlString];
            if ([files containsObject:url]) {
                [_maps addObject:[[BaseMap alloc] initWithLocalURL:url]];
                [files removeObject:url];
            }
        }
        //Add any other maps in filesystem (maybe added via iTunes) to end of list from defaults
        for (NSURL *url in files) {
            [_maps addObject:[[BaseMap alloc] initWithLocalURL:url]];
        }
    }
    return _maps;
}


#pragma mark - Public Methods

- (void) loadLocalMaps
{
    [self currentMap]; //acessing the current map will lazy load it and the map list
    return;
}

- (BaseMap *) mapAtIndex:(NSUInteger) index
{
    return (index < [self.maps count]) ? [self.maps objectAtIndex:index] : nil;
}

- (void) addMap:(BaseMap *)map
{
    [self insertMap:map atIndex:[self.maps count]];
}

- (void) insertMap:(BaseMap *)map atIndex:(NSUInteger)index
{
    if (!map)
        return;
    if ([self.maps containsObject:map])
        return;
    if ([self.maps count] < index)
        return;
    [map download];
    [self.maps insertObject:map atIndex:index];
    [self updateNSDefaults];
}

- (void) removeMap:(BaseMap *)map
{
    [map unload];
    [self.maps removeObject:map];
    if (self.currentMap == map)
        self.currentMap = nil;
    [self updateNSDefaults];
}

- (void) removeMapAtIndex:(NSUInteger)index
{
    if ([self.maps count] <= index)
        return;
    BaseMap *map = self.maps[index];
    [self removeMap:map];
}

- (void) moveMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex == toIndex)
        return;
    if ([self.maps count] <= fromIndex || [self.maps count] <= toIndex)
        return;
    BaseMap *temp = self.maps[fromIndex];
    [self.maps removeObjectAtIndex:fromIndex];
    [self.maps insertObject:temp atIndex:toIndex];
    [self updateNSDefaults];
}

- (BOOL) isOutdatedMap:(BaseMap *)map
{
    if (map.serverStatus == ServerStatusUnknown)
    {
        map.serverStatus = ServerStatusPending;
        //start background query of servers
        return NO;
    }
    if (map.serverStatus == ServerStatusResolved)
    {
        //return date < date
    }
    return NO;
}

- (BOOL) isOrphanMap:(BaseMap *)map
{
    if (map.serverStatus == ServerStatusUnknown)
    {
        map.serverStatus = ServerStatusPending;
        //start background query of servers
        return NO;
    }
    if (map.serverStatus == ServerStatusResolved)
    {
        //return date < date
    }
    return NO;
    
}

- (void) refreshServerStatusForMap:(BaseMap *)map
{
    if (self.cachedServerResponse)
    {
        //update map
    }
    else
    {
        dispatch_queue_t downloadQueue = dispatch_queue_create("serverStatusDownload", NULL);
        dispatch_async(downloadQueue, ^{
            [self downloadMapListFromServer];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self refreshServerStatusForMap:map];
                if ([self.delegate respondsToSelector:@selector(mapsDidFinishServerRequest:)])
                    [self.delegate mapsDidFinishServerRequest:self];
            });
        });
#pragma warning need to implement
        //call getServer maps on a background thread
        //callback should use the cached server response to update all maps
    }
}

- (void) downloadMapListFromServer
{
#pragma warning this is half-baked
    self.cachedServerResponse = nil;
    //FIXME - replace URL
    //FIXME - loop over multiple servers
    NSString *data = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"www.google.com"] usedEncoding:nil error:nil];
    if (data)
        //FIXME - check that the JSON is correct and builds the array we want.
        //FIXME - it needs to be an array of BaseMap
        self.cachedServerResponse = [data ags_JSONValue];
    //alert delegates of success or failure
}

- (NSArray *) serverMaps
{
    if (self.cachedServerResponse)
        //FIXME - should not include maps that are already downloaded and local
        return self.cachedServerResponse;
    else
    {
        //FIXME - only do this once; don't start a second thread if called while one is still working
        dispatch_queue_t downloadQueue = dispatch_queue_create("serverMapsDownload", NULL);
        dispatch_async(downloadQueue, ^{
            [self downloadMapListFromServer];
            dispatch_async(dispatch_get_main_queue(), ^{
                //FIXME - need to check for error and return appropriately
                if ([self.delegate respondsToSelector:@selector(mapsDidFinishServerRequest:)])
                    [self.delegate mapsDidFinishServerRequest:self];
            });
        });
        return nil;
    }
}


- (NSArray *) refreshServerMaps
{
    self.cachedServerResponse = nil;
    return [self getServerMaps];
}


- (NSArray *) getServerMaps
{
    if (self.cachedServerResponse)
        return self.cachedServerResponse;
    
    //we need to query the server(s) on a background thread
    //we will return nil until we get a response
    //the delegate will be informed when a response is available
    
#pragma warning need to use NSURLConnection, background thread and json decoding
    
    NSMutableArray * maps = [[NSMutableArray alloc] init];
    if (maps)
    {
        for (int i = 0; i < 2 + rand() % 5; i++)
        {
            [maps addObject:[BaseMap randomMap]];
        }
    }
    if ([self.delegate respondsToSelector:@selector(mapsDidFinishServerRequest:)])
        [self.delegate mapsDidFinishServerRequest:self];
    return [maps copy];
}


#pragma mark - Public Class Methods

+ (BaseMapManager *) sharedManager
{
    if (!_sharedManager)
        _sharedManager = [[BaseMapManager alloc] init];
    return _sharedManager;
}

+ (NSURL *) cacheDirectory
{
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
    return urls[0];
}

+ (NSURL *) documentsDirectory
{
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    return urls[0];
}


#pragma mark - Private Methods

- (NSArray *) /* of NSURL */ mapURLsInFileManager
{
    NSMutableArray *localUrls = [[NSMutableArray alloc] init];
    
    NSArray *documents = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtURL:[BaseMapManager documentsDirectory]
                          includingPropertiesForKeys:nil
                          options:NSDirectoryEnumerationSkipsHiddenFiles
                          error:nil];
    
    NSArray *caches = [[NSFileManager defaultManager]
                       contentsOfDirectoryAtURL:[BaseMapManager documentsDirectory]
                       includingPropertiesForKeys:nil
                       options:NSDirectoryEnumerationSkipsHiddenFiles
                       error:nil];
    
    documents = [documents arrayByAddingObjectsFromArray:caches];
    if (documents) {
        for (NSURL *url in documents) {
            if ([[url pathExtension] isEqualToString:TILE_CACHE_EXTENSION]) {
                [localUrls addObject:url];
            }
        }
    }
    return localUrls;
}


- (void) updateNSDefaults
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    if (self.currentMap && self.currentMap.localURL)
        [defaults setURL:self.currentMap.localURL forKey:DEFAULTS_KEY_CURRENT_MAP_URL];
    else
        [defaults setNilValueForKey:DEFAULTS_KEY_CURRENT_MAP_URL];
    
    NSMutableArray *localURLs = [[NSMutableArray alloc] initWithCapacity:[self.maps count]];
    for (BaseMap *map in self.maps)
    {
        [localURLs addObject:[map.localURL absoluteString]];
    }
    [defaults setValue:localURLs forKey:DEFAULTS_KEY_LOCAL_MAP_URLS];
}

@end
