//
//  Maps.m
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "Maps.h"

#define TILE_CACHE_EXTENSION @"tpk"

@interface Maps()

@property (strong, nonatomic) NSMutableArray *maps;

@end

@implementation Maps


#pragma mark - properties

- (NSUInteger) count {
    return self.maps.count;
}

- (void) setCurrentMap:(Map *)currentMap {
    if (_currentMap == currentMap)
        return;
    //allow setting the current map to nothing (usually when the current map is deleted)
    if (!currentMap || [self.maps containsObject:currentMap]) {
        _currentMap = currentMap;
        [self updateNSDefaults];
    }
}


#pragma mark - methods

- (Map *) mapAtIndex:(NSUInteger) index {
    return (index < [self.maps count]) ? [self.maps objectAtIndex:index] : nil;
}

- (void) addMap:(Map *)map {
    [self insertMap:map atIndex:[self.maps count]];
}

- (void) insertMap:(Map *)map atIndex:(NSUInteger)index {
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

- (void) removeMap:(Map *)map {
    [map unload];
    [self.maps removeObject:map];
    if (self.currentMap == map)
        self.currentMap = nil;
    [self updateNSDefaults];
}

- (void) removeMapAtIndex:(NSUInteger)index {
    if ([self.maps count] <= index)
        return;
    Map *map = self.maps[index];
    [self removeMap:map];
}

- (void) moveMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
    if (fromIndex == toIndex)
        return;
    if ([self.maps count] <= fromIndex || [self.maps count] <= toIndex)
        return;
    Map *temp = self.maps[fromIndex];
    [self.maps removeObjectAtIndex:fromIndex];
    [self.maps insertObject:temp atIndex:toIndex];
    [self updateNSDefaults];
}


#pragma mark - class methods

+ (NSArray *) serverMaps {
    NSMutableArray * maps = [[NSMutableArray alloc] init];
    if (maps) {
        for (int i = 0; i < 2 + rand() % 5; i++) {
            [maps addObject:[Map randomMap]];
        }
    }
    return [maps copy];
}


#pragma mark - private methods

- (NSMutableArray *)maps {
    if (!_maps) {
        _maps = [[NSMutableArray alloc] init];
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSArray *localMapURLs = [defaults valueForKey:@"LocalMapURLs"];
        NSMutableSet *files = [NSMutableSet setWithArray:[self mapURLsInFileManager]];
        // create maps in order from urls saved in defaults  IFF they are found in filesystem
        for (NSURL *url in localMapURLs) {
            if ([files containsObject:url]) {
                [_maps addObject:[[Map alloc] initWithLocalURL:url]];
                [files removeObject:url];
            }
        }
        //Add any other maps in filesystem (maybe added via iTunes) to end of list from defaults
        for (NSURL *url in files) {
            [_maps addObject:[[Map alloc] initWithLocalURL:url]];
        }
        
        // Get the current map from defaults 
        NSURL *currentMapURL = [defaults URLForKey:@"CurrentMapURL"];
        _currentMap = nil;
        for (Map *map in _maps) {
            if ([map.localURL isEqual:currentMapURL]) {
                _currentMap = map;
                break;
            }
        }
    }
    return _maps;
}

- (NSArray *) /* of NSURL */ mapURLsInFileManager
{
    
    NSMutableArray *localUrls = [[NSMutableArray alloc] init];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:documentsDirectory error:NULL];
    if (contents) {
        for (NSString *filename in contents) {
            if ([[filename pathExtension] isEqualToString:TILE_CACHE_EXTENSION]) {
                [localUrls addObject:[NSURL URLWithString:filename]];
            }
        }
    }
    return localUrls;
}


- (void) updateNSDefaults {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    if (self.currentMap && self.currentMap.localURL)
        [defaults setURL:self.currentMap.localURL forKey:@"CurrentMapURL"];
    else
        [defaults setNilValueForKey:@"CurrentMapURL"];
    
    NSMutableArray *localURLs = [[NSMutableArray alloc] initWithCapacity:[self.maps count]];
    for (Map *map in self.maps) {
        [localURLs addObject:map.localURL];
    }
    [defaults setValue:localURLs forKey:@"LocalMapURLs"];
}

@end
