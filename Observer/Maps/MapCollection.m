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
@property (nonatomic) BOOL isDownloading;
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
    if (self.isDownloading) {
        //TODO: keep track of request to release, so we can release when downloading is done.
        return;
    }
    @synchronized(self) {
        _sharedCollection = nil;
        _isLoaded = NO;
    }
}

static int _downloadsInProgress = 0;

+ (void)startDownloading
{
    _downloadsInProgress++;
}

+ (void)finishedDownloading
{
    _downloadsInProgress--;
}

+ (void)canceledDownloading
{
    _downloadsInProgress--;
}

+ (BOOL)isDownloading
{
    return 0 < _downloadsInProgress;
}




#pragma mark - property accessors

- (NSDate*) refreshDate
{
    return [Settings manager].mapRefreshDate;
}

- (void)setRefreshDate:(NSDate*)newDate
{
    [Settings manager].mapRefreshDate = newDate;
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
                    if (self.remoteItems.count == 0 || !self.refreshDate) {
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

//-(void)synchronize
//{
//    [self saveCache];
//}




#pragma mark - TableView Data Source Support

- (NSUInteger)numberOfLocalMaps
{
    return self.localItems.count;
}

- (NSUInteger)numberOfRemoteMaps
{
    return self.remoteItems.count;
}

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
    [item deleteFromFileSystem];
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




#pragma mark - private methods

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




#pragma mark - Cache operations

- (void)loadCache
{
    NSArray *mapURLs = [Settings manager].maps;
    [self.localItems removeAllObjects];
    [self.remoteItems removeAllObjects];
    for (NSURL *mapURL in mapURLs) {
        Map *map = [[Map alloc] initWithCachedPropertiesURL:mapURL];
        if (map) {
            if (map.isLocal) {
                [self.localItems addObject:map];
            } else {
                [self.remoteItems addObject:map];
            }
        }
    }
}

- (void)saveCache
{
    NSArray *items = [NSArray arrayWithArray:self.localItems];
    items = [items arrayByAddingObjectsFromArray:self.remoteItems];
    [Settings manager].maps = [items mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        return [obj plistURL];
    }];
}

//TODO load old cache if we are transitioning

//TODO: - consider NSDefaults as it does memory mapping and defered writes
//       this also make the class a singleton object
//
//+ (NSURL *)cacheFile
//{
//    static NSURL *_cacheFile = nil;
//    if (!_cacheFile) {
//        _cacheFile = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
//        _cacheFile = [_cacheFile URLByAppendingPathComponent:@"map_list.cache"];
//    }
//    return _cacheFile;
//}
//
////done on background thread
//- (void)loadCache
//{
//    NSArray *plist = [NSArray arrayWithContentsOfURL:[MapCollection cacheFile]];
//    for (id obj in plist) {
//        if ([obj isKindOfClass:[NSDate class]]) {
//            self.refreshDate = obj;
//        }
//        if ([obj isKindOfClass:[NSData class]]) {
//            id map = [NSKeyedUnarchiver unarchiveObjectWithData:obj];
//            if ([map isKindOfClass:[Map class]]) {
//                if (((Map *)map).isLocal) {
//                    [self.localItems addObject:map];
//                } else {
//                    [self.remoteItems addObject:map];
//                }
//            }
//        }
//    }
//}
//
////must be called by the thread that changes the model, after changes are complete.
////because of the enumeration of the model, it cannot be called while the model might be changed.
//- (void)saveCache
//{
//    //dispatching the creation of the archive data to a background thread could result in an exception
//    //if the UI thread then changed the model while it is being enumerated
//    NSMutableArray *plist = [NSMutableArray new];
//    if (self.refreshDate) {
//        [plist addObject:self.refreshDate];
//    }
//    for (Map *map in self.localItems) {
//        [plist addObject:[NSKeyedArchiver archivedDataWithRootObject:map]];
//    }
//    for (Map *map in self.remoteItems) {
//        [plist addObject:[NSKeyedArchiver archivedDataWithRootObject:map]];
//    }
//    //File save can be safely done on a background thread.
//    dispatch_async(dispatch_queue_create("gov.nps.akr.observer",DISPATCH_QUEUE_CONCURRENT), ^{
//        [plist writeToURL:[MapCollection cacheFile] atomically:YES];
//    });
//}




#pragma mark - Local Maps

//done on background thread
- (void)refreshLocalMaps
{
    //NOTE: compare file name (without path), because iOS is inconsistent about symbolic links at root of documents path
    NSMutableArray *localMapFileNames = [MapCollection mapFileNamesInDocumentsFolder];

    //remove cache items not in filesystem
    NSMutableIndexSet *indexesOfLocalMapsToRemove = [NSMutableIndexSet new];
    for (uint i = 0; i < self.localItems.count; i++) {
        Map *map = self.localItems[i];
        if (map.isLocal) {
            // A local file is the same as a map if the last path component is the same as the maps (local) tilecache URL
            NSUInteger index = [localMapFileNames indexOfObject:[map.tileCacheURL lastPathComponent]];
            if (index == NSNotFound) {
                [indexesOfLocalMapsToRemove addIndex:i];
                //make sure any other cached data about the map file is also deleted
                [map deleteFromFileSystem];
            } else {
                [localMapFileNames removeObjectAtIndex:index];
            }
        }
    }

    //add filesystem urls not in cache
    NSMutableArray *mapsToAdd = [NSMutableArray new];
    for (NSString *localMapFileName in localMapFileNames) {
        NSURL *mapUrl = [[MapCollection documentsDirectory] URLByAppendingPathComponent:localMapFileName];
        // TODO: Put up a modal, asking for details on the tile cache, i.e. name, author, date, description
        //       explain the importance of the attributes in identifying the map for reference for non-gps points
        //       maybe get the defaults from the esriinfo.xml file in the zipped tpk
        //       Map *newMap = [[Map alloc] initWithTileCacheURL:newUrl name:name author:author date:date description:description;
        Map *map = [[Map alloc] initWithTileCacheURL:mapUrl];
        if (map) {
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
            if (0 < indexesOfLocalMapsToRemove.count) {
                [self.localItems removeObjectsAtIndexes:indexesOfLocalMapsToRemove];
                [delegate collection:self removedLocalItemsAtIndexes:indexesOfLocalMapsToRemove];
            }
            if (0 < mapsToAdd.count) {
                NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.localItems.count, mapsToAdd.count)];
                [self.localItems addObjectsFromArray:mapsToAdd];
                [delegate collection:self addedLocalItemsAtIndexes:indexes];
            }
        });
    } else {
        [self.localItems removeObjectsAtIndexes:indexesOfLocalMapsToRemove];
        [self.localItems addObjectsFromArray:mapsToAdd];
    }
    //update cache
    if (0 < indexesOfLocalMapsToRemove.count || 0 < mapsToAdd.count) {
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
//Returns and array of map property dictionaries
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
                    [maps addObject:jsonItem];
//                    NSDictionary *item = jsonItem;
//                    Map *map = [[Map alloc] initWithRemoteProperties:item];
//                    if (map) {
//                        [maps addObject:map];
//                    }
                }
            }
        }
    }
    return maps;
}

//done on background thread
//serverMaps is an array of map property dictionaries
- (void)syncCacheWithServerMaps:(NSMutableArray *)serverMaps
{
    // we need to remove cached items not on the server,
    // we need to add items on the server not in the cache,
    // Do not add server items that match local items in the cache.
    // a cached item (on the server) might have an updated URL thumbnail, or any other property

    BOOL modelChanged = NO;

    //do not change the list while enumerating
    NSMutableDictionary *mapsToUpdate = [NSMutableDictionary new];

    //remove maps in remoteItems not in serverMaps
    NSMutableIndexSet *indexesOfRemoteMapsToRemove = [NSMutableIndexSet new];
    for (uint i = 0; i < self.remoteItems.count; i++) {
        Map *map = self.remoteItems[i];
        if (!map.isLocal) {
            NSUInteger index = [serverMaps indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [map isEqualToRemoteProperties:(NSDictionary *)obj];
            }];
            if (index == NSNotFound) {
                [indexesOfRemoteMapsToRemove addIndex:i];
                modelChanged = YES;
            } else {
                //update the url of cached server objects
                NSDictionary *remoteMapProperties = serverMaps[index];
                if ([map shouldUpdateToRemoteProperties:remoteMapProperties]) {
                    mapsToUpdate[[NSNumber numberWithInt:i]] = remoteMapProperties;
                    modelChanged = YES;
                }
                [serverMaps removeObjectAtIndex:index];
            }
        }
    }
    //add server maps not in cache (local or server)
    NSMutableArray *remotePropertiesToAdd = [NSMutableArray new];
    for (NSDictionary *properties in serverMaps) {
        NSUInteger localIndex = [self.localItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [(Map *)obj isEqualToRemoteProperties:properties];
        }];
        NSUInteger remoteIndex = [self.remoteItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [(Map *)obj isEqualToRemoteProperties:properties];
        }];
        if (localIndex == NSNotFound && remoteIndex == NSNotFound) {
            [remotePropertiesToAdd addObject:properties];
            modelChanged = YES;
        }
    }

    //convert remotePropertiesToAdd to mapsToAdd
    NSMutableArray *mapsToAdd = [NSMutableArray new];
    for (NSDictionary *properties in remotePropertiesToAdd) {
        Map *map = [[Map alloc] initWithRemoteProperties:properties];
        if (map) {
            [mapsToAdd addObject:map];
        }
    }

    //update lists and UI synchronosly on UI thread if there is a delegate
    id<CollectionChanged> delegate = self.delegate;
    if (delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            //ALERT: be sure to do the update before removing maps, since the indexes will change when removing
            for (id key in [mapsToUpdate allKeys]) {
                Map *map = self.remoteItems[[key unsignedIntegerValue]];
                NSDictionary *remoteMapProperties = [mapsToUpdate objectForKey:key];
                [map updateWithRemoteProperties:remoteMapProperties];
                [delegate collection:self changedRemoteItemsAtIndexes:[NSIndexSet indexSetWithIndex:[key unsignedIntegerValue]]];
            }
            if (0 < indexesOfRemoteMapsToRemove.count) {
                [self.remoteItems removeObjectsAtIndexes:indexesOfRemoteMapsToRemove];
                [delegate collection:self removedRemoteItemsAtIndexes:indexesOfRemoteMapsToRemove];
            }
            if (0 < mapsToAdd.count) {
                NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.remoteItems.count, mapsToAdd.count)];
                [self.remoteItems addObjectsFromArray:mapsToAdd];
                [delegate collection:self addedRemoteItemsAtIndexes:indexes];
            }
        });
    } else {
        //ALERT: be sure to do the update before removing maps, since the indexes will change when removing
        for (id key in [mapsToUpdate allKeys]) {
            Map *map = self.remoteItems[[key unsignedIntegerValue]];
            NSDictionary *remoteMapProperties = [mapsToUpdate objectForKey:key];
            [map updateWithRemoteProperties:remoteMapProperties];
        }
        [self.remoteItems removeObjectsAtIndexes:indexesOfRemoteMapsToRemove];
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
