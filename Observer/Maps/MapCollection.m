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
//selectedLocalIndex == NSNotFound  means that no item is selected
@property (nonatomic) NSUInteger selectedLocalIndex;
@property (nonatomic, strong) NSURL *documentsDirectory;
@property (nonatomic, strong) NSURL *cacheFile;
@property (nonatomic) BOOL isLoading;
@property (nonatomic) BOOL isLoaded;
@end

@implementation MapCollection


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

- (NSURL *)documentsDirectory
{
    if (!_documentsDirectory) {
        _documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    }
    return _documentsDirectory;
}

- (NSURL *)cacheFile
{
    if (!_cacheFile) {
        _cacheFile = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
        _cacheFile = [_cacheFile URLByAppendingPathComponent:@"map_list.cache"];
    }
    return _cacheFile;
}

- (void) setSelectedLocalIndex:(NSUInteger)selectedLocalIndex
{
    if (_selectedLocalIndex == selectedLocalIndex)
        return;
    if ( self.localItems.count <= selectedLocalIndex && selectedLocalIndex != NSNotFound) {
        return; //ignore bogus indexes
    }
    _selectedLocalIndex = selectedLocalIndex;
    [Settings manager].indexOfCurrentMap = selectedLocalIndex;
}


#pragma mark - TableView Data Soource Support

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

-(NSUInteger)numberOfLocalMaps
{
    return self.localItems.count;
}

-(NSUInteger)numberOfRemoteMaps
{
    return self.remoteItems.count;
}

-(void)removeLocalMapAtIndex:(NSUInteger)index
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
    if (index < self.selectedLocalIndex) {
        self.selectedLocalIndex = self.selectedLocalIndex - 1;
    }
}

-(void)moveLocalMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (self.localItems.count <= fromIndex || self.localItems.count <= toIndex) {
        AKRLog(@"Array index out of bounds in [MapCollection moveLocalMapAtIndex:%d toIndex:%d] size = %d",fromIndex,toIndex,self.localItems.count);
        return;
    }
    if (fromIndex == toIndex)
        return;

    //adjust the selected Index
    if (self.selectedLocalIndex == fromIndex) {
        self.selectedLocalIndex = toIndex;
    } else {
        if (fromIndex < self.selectedLocalIndex && self.selectedLocalIndex <= toIndex) {
            self.selectedLocalIndex = self.selectedLocalIndex - 1;
        } else {
            if (toIndex <= self.selectedLocalIndex && self.selectedLocalIndex < fromIndex) {
                self.selectedLocalIndex = self.selectedLocalIndex + 1;
            }
        }
    }

    //move the item
    id temp = self.localItems[fromIndex];
    [self.localItems removeObjectAtIndex:fromIndex];
    [self.localItems insertObject:temp atIndex:toIndex];
    [self saveCache];
}

-(void)moveRemoteMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (self.remoteItems.count <= fromIndex || self.remoteItems.count <= toIndex) {
        AKRLog(@"Array index out of bounds in [MapCollection moveRemoteMapAtIndex:%d toIndex:%d] size = %d",fromIndex,toIndex,self.remoteItems.count);
        return;
    }
    if (fromIndex == toIndex)
        return;
    id temp = self.remoteItems[fromIndex];
    [self.remoteItems removeObjectAtIndex:fromIndex];
    [self.remoteItems insertObject:temp atIndex:toIndex];
    [self saveCache];
}


#pragma mark - public methods

static MapCollection *_sharedCollection = nil;

+ (MapCollection *)sharedCollection
{
    if (!_sharedCollection) {
        _sharedCollection = [[MapCollection alloc] init];
    }
    return _sharedCollection;
}

+ (void)releaseSharedCollection {
    _sharedCollection = nil;
}

+ (BOOL) collectsURL:(NSURL *)url
{
    return [[url pathExtension] isEqualToString:MAP_EXT];
}


- (void)setSelectedLocalMap:(NSUInteger)index
{
    if (index < self.localItems.count) {
        self.selectedLocalIndex = index;
    }
}

- (Map *)selectedLocalMap
{
    if (self.localItems.count) {
        return self.localItems[self.selectedLocalIndex];
    } else {
        return nil;
    }
}

- (void)openWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    //Check and set of isLoading must be done on the main thread to guarantee there is no race condition.
    if (self.isLoaded) {
        if (completionHandler)
            completionHandler(self.localItems != nil  & self.remoteItems != nil);
    } else {
        if (self.isLoading) {
            //wait until loading is completed, then return;
            dispatch_async(dispatch_queue_create("gov.nps.akr.observer.mapcollection.open", DISPATCH_QUEUE_SERIAL), ^{
                //This task is serial with the task that will clear isLoading, so it will not run until loading is done;
                if (completionHandler) {
                    completionHandler(self.localItems != nil  & self.remoteItems != nil);
                }
            });
        }
        self.isLoading = YES;
        dispatch_async(dispatch_queue_create("gov.nps.akr.observer.mapcollection.open", DISPATCH_QUEUE_SERIAL), ^{
            [self loadAndCorrectListOfMaps];
            self.isLoaded = YES;
            self.isLoading = NO;
            if (completionHandler) {
                completionHandler(self.localItems != nil  & self.remoteItems != nil);
            }
        });
    }
}

- (BOOL)openURL:(NSURL *)url
{
    //FIXME: SProtocol returns the protocol, Survey returns BOOL, which should I use?
    return ![self openURL:url saveCache:YES];
}


- (void)refreshWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
        self.refreshDate = [NSDate date];
        BOOL success = [self refreshRemoteMaps] && [self refreshLocalMaps];
        //assume that changes were made to the model and save the cache.
        //If there is a delegate, then it must be queued up on main thread, because the model changes occur there
        if (self.delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self saveCache];
            });
        } else {
            [self saveCache];
        }
        if (completionHandler) {
            completionHandler(success);
        }
    });
}


-(void)prepareToDownloadMapAtIndex:(NSUInteger)index
{
    if (self.remoteItems.count <= index) {
        AKRLog(@"Array index out of bounds in [MapCollection prepareToDownloadMapAtIndex:%d]; size = %d",index,self.remoteItems.count);
        return;
    }
    [self.remoteItems[index] prepareToDownload];
}

- (void)cancelDownloadMapAtIndex:(NSUInteger)index
{
    if (self.remoteItems.count <= index) {
        AKRLog(@"Array index out of bounds in [MapCollection cancelDownloadMapAtIndex:%d]; size = %d",index,self.remoteItems.count);
        return;
    }
    [self.remoteItems[index] stopDownload];
}

//- (void)downloadMapAtIndex:(NSUInteger)index WithCompletionHandler:(void (^)(BOOL success))completionHandler
//{
//    //if (self.remoteItems.count <= index) return; //safety check
//    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
//        Map *map = [self remoteMapAtIndex:index];
//        NSURL *newUrl = [self.documentsDirectory URLByAppendingPathComponent:map.url.lastPathComponent];
//        newUrl = [newUrl URLByUniquingPath];
//        BOOL success = [map downloadToURL:newUrl];
//        if (success) {
//            if (self.delegate) {
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    [self.remoteItems removeObjectAtIndex:index];
//                    [self.delegate collection:self removedRemoteItemsAtIndexes:[NSIndexSet indexSetWithIndex:index]];
//                    [self.localItems insertObject:map atIndex:0];
//                    [self.delegate collection:self addedLocalItemsAtIndexes:[NSIndexSet indexSetWithIndex:0]];
//                    [self saveCache];
//                });
//            } else {
//                [self.remoteItems removeObjectAtIndex:index];
//                [self.localItems insertObject:map atIndex:0];
//                [self saveCache];
//            }
//        }
//        if (completionHandler) {
//            completionHandler(success);
//        }
//    });
//}

- (void) moveRemoteMapAtIndex:(NSUInteger)fromIndex toLocalMapAtIndex:(NSUInteger)toIndex
{
    if (self.remoteItems.count <= fromIndex || self.localItems.count < toIndex) {
        AKRLog(@"Array index out of bounds in [MapCollection moveRemoteMapAtIndex:%d toLocalMapAtIndex:%d] size = (%d,%d)",fromIndex,toIndex,self.remoteItems.count,self.localItems.count);
        return;
    }
    Map *map = [self.remoteItems objectAtIndex:fromIndex];
    [self.remoteItems removeObjectAtIndex:fromIndex];
    [self.delegate collection:self removedRemoteItemsAtIndexes:[NSIndexSet indexSetWithIndex:fromIndex]];
    [self.localItems insertObject:map atIndex:toIndex];
    [self.delegate collection:self addedLocalItemsAtIndexes:[NSIndexSet indexSetWithIndex:toIndex]];
    //Update the selectedIndex, unless this the list was empty (self.selectedIndex was already 0), 
    if (toIndex <= self.selectedLocalIndex && 1 < self.localItems.count ) {
        self.selectedLocalIndex++;
    }
    [self saveCache];
}

-(void)synchronize
{
    [self saveCache];
}


#pragma mark - private methods

- (void)loadAndCorrectListOfMaps
{
    //TODO: compare with similar method in SurveyCollection
    //temporarily remove the delegate so that updates are not sent for the bulk updates before the UI might be ready
    //  currently unnecessary, since open is only called when the delegate is nil;
    id savedDelegate = self.delegate;
    self.delegate = nil;
    [self loadCache];
    [self refreshLocalMaps];
    [self saveCache];
    //Get the selected index (we can't do this in an accessor, because there isn't a no valid 'data not loaded' sentinal)
    _selectedLocalIndex = [Settings manager].indexOfCurrentMap;
    [self checkAndFixSelectedIndex];
    self.delegate = savedDelegate;

}

//TODO: - consider NSDefaults as it does memory mapping and defered writes
//       this also make the class a singleton object

//done on background thread
- (void)loadCache
{
    NSArray *plist = [NSArray arrayWithContentsOfURL:self.cacheFile];
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
        [plist writeToURL:self.cacheFile atomically:YES];
    });
}

//done on callers thread
- (Map *)openURL:(NSURL *)url saveCache:(BOOL)shouldSaveCache
{
    NSURL *newUrl = [self.documentsDirectory URLByAppendingPathComponent:url.lastPathComponent];
    newUrl = [newUrl URLByUniquingPath];
    NSError *error = nil;
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:newUrl error:&error];
    if (error) {
        AKRLog(@"MapCollection.openURL: Unable to copy %@ to %@; error: %@",url, newUrl, error);
        return nil;
    }
    Map *map = [[Map alloc] initWithLocalTileCache:newUrl];
    if (!map.tileCache) {
        AKRLog(@"data in %@ was not a valid map object",url.lastPathComponent);
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        [[NSFileManager defaultManager] removeItemAtURL:newUrl error:nil];
        return nil;
    }
    //Check if the map is already in our local list
    NSUInteger localIndex = [self.localItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [map isEqualtoMap:obj];
    }];
    if (localIndex != NSNotFound)
    {
        AKRLog(@"We already have the map in %@.  Ignoring the duplicate.",url.lastPathComponent);
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        [[NSFileManager defaultManager] removeItemAtURL:newUrl error:nil];
        return self.localItems[localIndex];
    }
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

    //Adding a new local map, might need to remove the same remote map
    NSUInteger remoteIndex = [self.remoteItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [map isEqualtoMap:obj];
    }];

    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.localItems insertObject:map atIndex:0];
            [self.delegate collection:self addedLocalItemsAtIndexes:[NSIndexSet indexSetWithIndex:0]];
            if (remoteIndex != NSNotFound)
            {
                [self.remoteItems removeObjectAtIndex:remoteIndex];
                [self.delegate collection:self addedLocalItemsAtIndexes:[NSIndexSet indexSetWithIndex:remoteIndex]];
            }
            if (shouldSaveCache) {
                [self saveCache];
            }
        });
    } else {
        [self.localItems insertObject:map atIndex:0];
        if (remoteIndex != NSNotFound)
        {
            [self.remoteItems removeObjectAtIndex:remoteIndex];
            [self.delegate collection:self addedLocalItemsAtIndexes:[NSIndexSet indexSetWithIndex:remoteIndex]];
        }
        if (shouldSaveCache) {
            [self saveCache];
        }
    }
    return map;
}

//done on background thread
- (BOOL)refreshLocalMaps
{
    [self syncWithFileSystem];
    return YES;
}

//done on background thread
- (void)syncWithFileSystem
{
    //urls in the maps directory
    NSMutableArray *mapUrlsInDocumentsFolder = [self mapURLsInFileManager];

    //remove cache items not in filesystem
    NSMutableIndexSet *itemsToRemove = [NSMutableIndexSet new];
    for (uint i = 0; i < self.localItems.count; i++) {
        Map *p = self.localItems[i];
        if (p.isLocal) {
            NSUInteger index = [mapUrlsInDocumentsFolder indexOfObject:p.url];
            if (index == NSNotFound) {
                [itemsToRemove addIndex:i];
                //deleting a map with iTunes will leave the thumbnail behind
                [[NSFileManager defaultManager] removeItemAtURL:p.thumbnailUrl error:nil];
            } else {
                [mapUrlsInDocumentsFolder removeObjectAtIndex:index];
            }
        }
    }

    //add filesystem urls not in cache
    NSMutableArray *mapsToAdd = [NSMutableArray new];
    for (NSURL *url in mapUrlsInDocumentsFolder) {
        Map *map = [[Map alloc] initWithLocalTileCache:url];
        if (!map.tileCache) {
            AKRLog(@"data at %@ was not a valid map object",url);
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
        [mapsToAdd addObject:map];
    }

    //update lists and UI synchronously on UI thread if there is a delegate
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (0 < itemsToRemove.count) {
                [self.localItems removeObjectsAtIndexes:itemsToRemove];
                [self.delegate collection:self removedLocalItemsAtIndexes:itemsToRemove];
            }
            if (0 < mapsToAdd.count) {
                NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.localItems.count, mapsToAdd.count)];
                [self.localItems addObjectsFromArray:mapsToAdd];
                [self.delegate collection:self addedLocalItemsAtIndexes:indexes];
            }
            [self checkAndFixSelectedIndex];
        });
    } else {
        [self.localItems removeObjectsAtIndexes:itemsToRemove];
        [self.localItems addObjectsFromArray:mapsToAdd];
        [self checkAndFixSelectedIndex];
    }
}

- (NSMutableArray *) /* of NSURL */ mapURLsInFileManager
{
    NSMutableArray *localUrls = [[NSMutableArray alloc] init];

    NSArray *documents = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtURL:self.documentsDirectory
                          includingPropertiesForKeys:nil
                          options:NSDirectoryEnumerationSkipsHiddenFiles
                          error:nil];
    if (documents) {
        for (NSURL *url in documents) {
            if ([[url pathExtension] isEqualToString:MAP_EXT]) {
                [localUrls addObject:url];
            }
        }
    }
    return localUrls;
}


//done on background thread
- (BOOL)refreshRemoteMaps
{
    NSURL *url = [Settings manager].urlForMaps;
    NSMutableArray *serverMaps = [self fetchMapListFromURL:url];
    if (serverMaps) {
        [self syncCacheWithServerMaps:serverMaps];
        return YES;
    }
    return NO;
}


//done on background thread
- (NSMutableArray *)fetchMapListFromURL:(NSURL *)url
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
-  (BOOL)syncCacheWithServerMaps:(NSMutableArray *)serverMaps
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
                return [p isEqualtoMap:obj];
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
        //
        NSUInteger localIndex = [self.localItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [map isEqualtoMap:obj];
        }];
        NSUInteger remoteIndex = [self.remoteItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [map isEqualtoMap:obj];
        }];
        if (localIndex == NSNotFound && remoteIndex == NSNotFound) {
            [mapsToAdd addObject:map];
            modelChanged = YES;
        }
    }
    //update lists and UI synchronosly on UI thread if there is a delegate
    if (self.delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (id key in [mapsToUpdate allKeys]) {
                self.remoteItems[[key unsignedIntegerValue]] = [mapsToUpdate objectForKey:key];
                [self.delegate collection:self changedRemoteItemsAtIndexes:[NSIndexSet indexSetWithIndex:[key unsignedIntegerValue]]];
            }
            if (0 < itemsToRemove.count) {
                [self.remoteItems removeObjectsAtIndexes:itemsToRemove];
                [self.delegate collection:self removedRemoteItemsAtIndexes:itemsToRemove];
            }
            if (0 < mapsToAdd.count) {
                NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.remoteItems.count, mapsToAdd.count)];
                [self.remoteItems addObjectsFromArray:mapsToAdd];
                [self.delegate collection:self addedRemoteItemsAtIndexes:indexes];
            }
        });
    } else {
        for (id key in [mapsToUpdate allKeys]) {
            self.remoteItems[[key unsignedIntegerValue]] = [mapsToUpdate objectForKey:key];
        }
        [self.remoteItems removeObjectsAtIndexes:itemsToRemove];
        [self.remoteItems addObjectsFromArray:mapsToAdd];
    }
    return modelChanged;
}

- (void) checkAndFixSelectedIndex
{
    if (self.localItems.count <= self.selectedLocalIndex) {
        self.selectedLocalIndex = self.localItems.count - 1;
    }
}


@end
