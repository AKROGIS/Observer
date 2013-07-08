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

@end

@implementation BaseMapManager

#pragma mark - singleton setup
//This is not a "true" singleton, it is still possible to create another object with [[BaseMapManager alloc] init]
//I only need/want one shareable instance in my app, so I will use a factory method to return the sharedManager

static BaseMapManager * _sharedManager;

+ (BaseMapManager *) sharedManager
{
    if (!_sharedManager) _sharedManager = [[BaseMapManager alloc] init];
    return _sharedManager;
}


#pragma mark - properties

- (NSUInteger) count {
    return [self.maps count];
}

@synthesize currentMap = _currentMap; //required since I'm implementing a setter and getter

- (void) setCurrentMap:(BaseMap *)currentMap {
    if (_currentMap == currentMap)
        return;
    //allow setting the current map to nothing (usually when the current map is deleted)
    if (!currentMap || [self.maps containsObject:currentMap]) {
        _currentMap = currentMap;
        [self updateNSDefaults];
    }
}

- (BaseMap *)currentMap
{
    if (!_currentMap) {
        // Get the current map from defaults
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSURL *currentMapURL = [defaults URLForKey:DEFAULTS_KEY_CURRENT_MAP_URL];
        for (BaseMap *map in self.maps) {
            if ([map.localURL isEqual:currentMapURL]) {
                _currentMap = map;
                break;
            }
        }
    }
    return _currentMap;
}


#pragma mark - methods

- (BaseMap *) mapAtIndex:(NSUInteger) index {
    return (index < [self.maps count]) ? [self.maps objectAtIndex:index] : nil;
}

- (void) addMap:(BaseMap *)map {
    [self insertMap:map atIndex:[self.maps count]];
}

- (void) insertMap:(BaseMap *)map atIndex:(NSUInteger)index {
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

- (void) removeMap:(BaseMap *)map {
    [map unload];
    [self.maps removeObject:map];
    if (self.currentMap == map)
        self.currentMap = nil;
    [self updateNSDefaults];
}

- (void) removeMapAtIndex:(NSUInteger)index {
    if ([self.maps count] <= index)
        return;
    BaseMap *map = self.maps[index];
    [self removeMap:map];
}

- (void) moveMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
    if (fromIndex == toIndex)
        return;
    if ([self.maps count] <= fromIndex || [self.maps count] <= toIndex)
        return;
    BaseMap *temp = self.maps[fromIndex];
    [self.maps removeObjectAtIndex:fromIndex];
    [self.maps insertObject:temp atIndex:toIndex];
    [self updateNSDefaults];
}

static NSArray * _cachedServerResponse;

- (NSArray *) refreshServerMaps {
    _cachedServerResponse = nil;
    return [self getServerMaps];
}

- (NSArray *) getServerMaps {
    if (_cachedServerResponse)
        return _cachedServerResponse;
    
    //we need to query the server(s) on a background thread
    //we will return nil until we get a response
    //the delegate will be informed when a response is available
    
    NSMutableArray * maps = [[NSMutableArray alloc] init];
    if (maps) {
        for (int i = 0; i < 2 + rand() % 5; i++) {
            [maps addObject:[BaseMap randomMap]];
        }
    }
#pragma warning how do we use a delegate in a class method
    //if ([self.delegate respondsToSelector:@selector(mapsDidFinishServerRequest:)]) {
    //    [self.delegate mapsDidFinishServerRequest:self];
    //}
    return [maps copy];
}



#pragma mark - class methods

+ (NSURL *) cacheDirectory {
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
    return urls[0];
}

+ (NSURL *) documentsDirectory {
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    return urls[0];
}

#pragma mark - private methods

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


- (void) updateNSDefaults {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    if (self.currentMap && self.currentMap.localURL)
        [defaults setURL:self.currentMap.localURL forKey:DEFAULTS_KEY_CURRENT_MAP_URL];
    else
        [defaults setNilValueForKey:DEFAULTS_KEY_CURRENT_MAP_URL];
    
    NSMutableArray *localURLs = [[NSMutableArray alloc] initWithCapacity:[self.maps count]];
    for (BaseMap *map in self.maps) {
        [localURLs addObject:[map.localURL absoluteString]];
    }
    [defaults setValue:localURLs forKey:DEFAULTS_KEY_LOCAL_MAP_URLS];
}

@end
