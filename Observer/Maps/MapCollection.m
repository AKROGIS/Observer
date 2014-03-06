//
//  MapCollection.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "MapCollection.h"
#import "NSArray+map.h"
#import "NSURL+unique.h"
#import "Settings.h"

@interface MapCollection()
@property (nonatomic, strong) NSMutableArray *localItems;  // of Map
@property (nonatomic, strong) NSMutableArray *remoteItems; // of Map
@end

@implementation MapCollection

#pragma mark - singleton

static MapCollection *_sharedCollection = nil;
static BOOL _isLoaded = NO;

+ (MapCollection *)sharedCollection {
    @synchronized(self) {
        if (_sharedCollection == nil) {
            _sharedCollection = [[super allocWithZone:NULL] init];
        }
    }
    return _sharedCollection;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedCollection];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

+ (void)releaseSharedCollection {
    @synchronized(self) {
        _sharedCollection = nil;
        _isLoaded = NO;
    }
}




#pragma mark - private properties

- (NSMutableArray *)localItems
{
    if (!_localItems) {
        _localItems = [NSMutableArray new];
    }
    return _localItems;
}

- (NSMutableArray *)remoteItems
{
    if (!_remoteItems) {
        _remoteItems = [NSMutableArray new];
    }
    return _remoteItems;
}




#pragma mark - TableView Data Source Support

- (Map *)localMapAtIndex:(NSUInteger)index
{
    if (self.localItems.count <= index) {
        AKRLog(@"Array index out of bounds in [MapCollection localMapAtIndex:%d]; size = %d",index,self.localItems.count);
        return nil;
    }
    return self.localItems[index];
}

- (Map *)remoteMapAtIndex:(NSUInteger)index
{
    if (self.remoteItems.count <= index) {
        AKRLog(@"Array index out of bounds in [MapCollection remoteMapAtIndex:%d]; size = %d",index,self.remoteItems.count);
        return nil;
    }
    return self.remoteItems[index];
}

- (NSUInteger)numberOfLocalMaps
{
    return self.localItems.count;
}

- (NSUInteger)numberOfRemoteMaps
{
    return self.remoteItems.count;
}

- (void)insertLocalMap:(Map *)map atIndex:(NSUInteger)index
{
    NSAssert(index <= self.localItems.count, @"Array index out of bounds in [MapCollection insertLocalMapAtIndex:%d]; size = %d",index,self.localItems.count);
    [self.localItems insertObject:map atIndex:index];
    [self saveCache];
}

- (void)removeLocalMapAtIndex:(NSUInteger)index
{
    if (self.localItems.count <= index) {
        AKRLog(@"Array index out of bounds in [MapCollection removeLocalMapAtIndex:%d] size = %d",index,self.localItems.count);
        return;
    }
    Map *item = [self localMapAtIndex:index];
    [[NSFileManager defaultManager] removeItemAtURL:item.url error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:item.thumbnailUrl error:nil];
    [self.localItems removeObjectAtIndex:index];
    [self saveCache];
}

- (void)removeRemoteMapAtIndex:(NSUInteger)index
{
    if (self.remoteItems.count <= index) {
        AKRLog(@"Array index out of bounds in [MapCollection removeRemoteMapAtIndex:%d] size = %d",index,self.remoteItems.count);
        return;
    }
    [self.remoteItems removeObjectAtIndex:index];
    [self saveCache];
}

- (void)moveLocalMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex == toIndex)
        return;
    NSAssert(fromIndex < self.localItems.count && toIndex < self.localItems.count, @"Array index out of bounds in [MapCollection moveLocalMapAtIndex:%d toIndex:%d] size = %d",fromIndex,toIndex,self.localItems.count);
    id temp = self.localItems[fromIndex];
    [self.localItems removeObjectAtIndex:fromIndex];
    [self.localItems insertObject:temp atIndex:toIndex];
    [self saveCache];
}

- (void)moveRemoteMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex == toIndex)
        return;
    NSAssert(fromIndex < self.remoteItems.count && toIndex < self.remoteItems.count, @"Array index out of bounds in [MapCollection moveRemoteMapAtIndex:%d toIndex:%d] size = %d",fromIndex,toIndex,self.remoteItems.count);
    id temp = self.remoteItems[fromIndex];
    [self.remoteItems removeObjectAtIndex:fromIndex];
    [self.remoteItems insertObject:temp atIndex:toIndex];
    [self saveCache];
}




#pragma mark - public methods

+ (BOOL)collectsURL:(NSURL *)url
{
    return [[url pathExtension] isEqualToString:MAP_EXT];
}

- (void)openWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    static BOOL isLoading = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        //Check and set self.isLoading on the main thread to guarantee there is no race condition.
        if (_isLoaded) {
            if (completionHandler)
                completionHandler(self.localItems != nil  && self.remoteItems != nil);
        } else {
            if (isLoading) {
                //wait until loading is completed, then return;
                dispatch_async(dispatch_queue_create("gov.nps.akr.observer.mapcollection.open", DISPATCH_QUEUE_SERIAL), ^{
                    //This task is serial with the task that will clear isLoading, so it will not run until loading is done;
                    if (completionHandler) {
                        completionHandler(self.localItems != nil && self.remoteItems != nil);
                    }
                });
            } else {
                isLoading = YES;
                dispatch_async(dispatch_queue_create("gov.nps.akr.observer.mapcollection.open", DISPATCH_QUEUE_SERIAL), ^{
                    [self loadCache];
                    [self refreshLocalMaps];
                    if (!self.refreshDate) {
                        [self refreshRemoteMaps];
                        self.refreshDate = [NSDate date];
                    }
                    _isLoaded = YES;
                    isLoading = NO;
                    if (completionHandler) {
                        completionHandler(self.localItems != nil && self.remoteItems != nil);
                    }
                });
            }
        }
    });
}

- (void)refreshWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
        self.refreshDate = [NSDate date];
        [self refreshLocalMaps];
        BOOL success = [self refreshRemoteMaps];
        if (completionHandler) {
            completionHandler(success);
        }
    });
}

-(void)synchronize
{
    [self saveCache];
}




#pragma mark - private methods

#pragma mark - Cache operations

//TODO: - consider NSDefaults as it does memory mapping and defered writes
//       this also make the class a singleton object

+ (NSURL *)cacheFile
{
    static NSURL *_cacheFile = nil;
    if (!_cacheFile) {
        _cacheFile = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
        _cacheFile = [_cacheFile URLByAppendingPathComponent:@"map_list.cache"];
    }
    return _cacheFile;
}

//done on background thread
- (void)loadCache
{
    NSArray *plist = [NSArray arrayWithContentsOfURL:[MapCollection cacheFile]];
    for (id obj in plist) {
        if ([obj isKindOfClass:[NSDate class]]) {
            self.refreshDate = obj;
        }
        if ([obj isKindOfClass:[NSData class]]) {
            id map = [NSKeyedUnarchiver unarchiveObjectWithData:obj];
            if ([map isKindOfClass:[Map class]]) {
                if (((Map *)map).isLocal) {
                    [self.localItems addObject:map];
                } else {
                    [self.remoteItems addObject:map];
                }
            }
        }
    }
}

//must be called by the thread that changes the model, after changes are complete.
//because of the enumeration of the model, it cannot be called while the model might be changed.
- (void)saveCache
{
    //dispatching the creation of the archive data to a background thread could result in an exception
    //if the UI thread then changed the model while it is being enumerated
    NSMutableArray *plist = [NSMutableArray new];
    if (self.refreshDate) {
        [plist addObject:self.refreshDate];
    }
    for (Map *map in self.localItems) {
        [plist addObject:[NSKeyedArchiver archivedDataWithRootObject:map]];
    }
    for (Map *map in self.remoteItems) {
        [plist addObject:[NSKeyedArchiver archivedDataWithRootObject:map]];
    }
    //File save can be safely done on a background thread.
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer",DISPATCH_QUEUE_CONCURRENT), ^{
        [plist writeToURL:[MapCollection cacheFile] atomically:YES];
    });
}




#pragma mark - Local Maps

//done on background thread
- (void)refreshLocalMaps
{
    //NOTE: compare file name (without path), because iOS is inconsistent about symbolic links at root of documents path
    NSMutableArray *localMapFileNames = [MapCollection mapFileNamesInDocumentsFolder];

    //remove cache items not in filesystem
    NSMutableIndexSet *itemsToRemove = [NSMutableIndexSet new];
    for (uint i = 0; i < self.localItems.count; i++) {
        Map *map = self.localItems[i];
        if (map.isLocal) {
            NSUInteger index = [localMapFileNames indexOfObject:[map.url lastPathComponent]];
            if (index == NSNotFound) {
                [itemsToRemove addIndex:i];
                //deleting a map with iTunes will leave the thumbnail behind
                [[NSFileManager defaultManager] removeItemAtURL:map.thumbnailUrl error:nil];
            } else {
                [localMapFileNames removeObjectAtIndex:index];
            }
        }
    }

    //add filesystem urls not in cache
    NSMutableArray *mapsToAdd = [NSMutableArray new];
    for (NSString *localMapFileName in localMapFileNames) {
        NSURL *mapUrl = [[MapCollection documentsDirectory] URLByAppendingPathComponent:localMapFileName];
        Map *map = [[Map alloc] initWithLocalTileCache:mapUrl];
        if (map.isValid) {
            [mapsToAdd addObject:map];
        } else {
            AKRLog(@"data at %@ was not a valid map object",localMapFileName);
            [[NSFileManager defaultManager] removeItemAtURL:mapUrl error:nil];
        }
    }

    //update lists and UI synchronously on UI thread if there is a delegate
    id<CollectionChanged> delegate = self.delegate;
    if (delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (0 < itemsToRemove.count) {
                [self.localItems removeObjectsAtIndexes:itemsToRemove];
                [delegate collection:self removedLocalItemsAtIndexes:itemsToRemove];
            }
            if (0 < mapsToAdd.count) {
                NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.localItems.count, mapsToAdd.count)];
                [self.localItems addObjectsFromArray:mapsToAdd];
                [delegate collection:self addedLocalItemsAtIndexes:indexes];
            }
        });
    } else {
        [self.localItems removeObjectsAtIndexes:itemsToRemove];
        [self.localItems addObjectsFromArray:mapsToAdd];
    }
    //update cache
    if (0 < itemsToRemove.count || 0 < mapsToAdd.count) {
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self saveCache];
            });
        } else {
            [self saveCache];
        }
    }
}

+ (NSMutableArray *) /* of NSString */ mapFileNamesInDocumentsFolder
{
    NSError *error = nil;
    NSArray *documents = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtURL:self.documentsDirectory
                          includingPropertiesForKeys:nil
                          options:NSDirectoryEnumerationSkipsHiddenFiles
                          error:&error];
    if (documents) {
        NSMutableArray *localFileNames = [NSMutableArray new];
        for (NSURL *url in documents) {
            if ([MapCollection collectsURL:url]) {
                [localFileNames addObject:[url lastPathComponent]];
            }
        }
        return localFileNames;
    }
    AKRLog(@"Unable to enumerate %@: %@",[self.documentsDirectory lastPathComponent], error.localizedDescription);
    return nil;
}

+ (NSURL *)documentsDirectory
{
    static NSURL *_documentsDirectory = nil;
    if (!_documentsDirectory) {
        _documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    }
    return _documentsDirectory;
}




#pragma mark - Remote Maps

//done on background thread
- (BOOL)refreshRemoteMaps
{
    NSURL *url = [Settings manager].urlForMaps;
    NSMutableArray *serverMaps = [MapCollection fetchMapListFromURL:url];
    if (serverMaps) {
        [self syncCacheWithServerMaps:serverMaps];
        return YES;
    }
    return NO;
}

//done on background thread
+ (NSMutableArray *)fetchMapListFromURL:(NSURL *)url
{
    NSMutableArray *maps = nil;
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (data) {
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([json isKindOfClass:[NSArray class]])
        {
            maps = [NSMutableArray new];
            NSArray *items = json;
            for (id jsonItem in items) {
                if ([jsonItem isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *item = jsonItem;
                    Map *map = [[Map alloc] initWithDictionary:item];
                    if (map) {
                        [maps addObject:map];
                    }
                }
            }
        }
    }
    return maps;
}

//done on background thread
- (void)syncCacheWithServerMaps:(NSMutableArray *)serverMaps
{
    // return value of YES means changes were made and the caller should update the cache.
    // we need to remove cached items not on the server,
    // we need to add items on the server not in the cache,
    // Do not add server items that match local items in the cache.
    // a cached item (on the server) might have an updated URL

    BOOL modelChanged = NO;

    //do not change the list while enumerating
    NSMutableDictionary *mapsToUpdate = [NSMutableDictionary new];

    //remove maps in remoteItems not in serverMaps
    NSMutableIndexSet *itemsToRemove = [NSMutableIndexSet new];
    for (uint i = 0; i < self.remoteItems.count; i++) {
        Map *p = self.remoteItems[i];
        if (!p.isLocal) {
            NSUInteger index = [serverMaps  indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [p isEqualToMap:obj];
            }];
            if (index == NSNotFound) {
                [itemsToRemove addIndex:i];
                modelChanged = YES;
            } else {
                //update the url of cached server objects
                Map *serverMap = serverMaps[index];
                if (![p.url isEqual:serverMap.url]) {
                    mapsToUpdate[[NSNumber numberWithInt:i]] = serverMap;
                    modelChanged = YES;
                }
                [serverMaps removeObjectAtIndex:index];
            }
        }
    }
    //add server maps not in cache (local or server)
    NSMutableArray *mapsToAdd = [NSMutableArray new];
    for (Map *map in serverMaps) {
        NSUInteger localIndex = [self.localItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [map isEqualToMap:obj];
        }];
        NSUInteger remoteIndex = [self.remoteItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [map isEqualToMap:obj];
        }];
        if (localIndex == NSNotFound && remoteIndex == NSNotFound) {
            [mapsToAdd addObject:map];
            modelChanged = YES;
        }
    }
    //update lists and UI synchronosly on UI thread if there is a delegate
    id<CollectionChanged> delegate = self.delegate;
    if (delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (id key in [mapsToUpdate allKeys]) {
                self.remoteItems[[key unsignedIntegerValue]] = [mapsToUpdate objectForKey:key];
                [delegate collection:self changedRemoteItemsAtIndexes:[NSIndexSet indexSetWithIndex:[key unsignedIntegerValue]]];
            }
            if (0 < itemsToRemove.count) {
                [self.remoteItems removeObjectsAtIndexes:itemsToRemove];
                [delegate collection:self removedRemoteItemsAtIndexes:itemsToRemove];
            }
            if (0 < mapsToAdd.count) {
                NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.remoteItems.count, mapsToAdd.count)];
                [self.remoteItems addObjectsFromArray:mapsToAdd];
                [delegate collection:self addedRemoteItemsAtIndexes:indexes];
            }
        });
    } else {
        for (id key in [mapsToUpdate allKeys]) {
            self.remoteItems[[key unsignedIntegerValue]] = [mapsToUpdate objectForKey:key];
        }
        [self.remoteItems removeObjectsAtIndexes:itemsToRemove];
        [self.remoteItems addObjectsFromArray:mapsToAdd];
    }
    //update cache
    if (modelChanged) {
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self saveCache];
            });
        } else {
            [self saveCache];
        }
    }
}

@end
