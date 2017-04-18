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
#import "AKRLog.h"

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
    //TODO: setting _sharedCollection to nil, only releases the class' copy of the instance.
    //The instance will remain alive if something (i.e. a callback block) has retained a copy.
    //if _sharedCollection is nil, I might end up creating a second collection (leading to chaos)
    //for now, it is safer to just prohibit releasing, especially with a async downloading.
    return;

//    if (self.isDownloading) {
//        //TODO: keep track of request to release, so we can release when downloading is done.
//        return;
//    }
//    @synchronized(self) {
//        _sharedCollection = nil;
//        _isLoaded = NO;
//    }
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
        AKRLog(@"Array index out of bounds in [MapCollection localMapAtIndex:%lu]; size = %lu",(unsigned long)index,(unsigned long)self.localItems.count);
        return nil;
    }
    return self.localItems[index];
}

- (Map *)remoteMapAtIndex:(NSUInteger)index
{
    if (self.remoteItems.count <= index) {
        AKRLog(@"Array index out of bounds in [MapCollection remoteMapAtIndex:%lu]; size = %lu",(unsigned long)index,(unsigned long)self.remoteItems.count);
        return nil;
    }
    return self.remoteItems[index];
}

- (void)insertLocalMap:(Map *)map atIndex:(NSUInteger)index
{
    [self.localItems insertObject:map atIndex:index];
    [self saveCache];
}

- (void)removeLocalMapAtIndex:(NSUInteger)index
{
    if (self.localItems.count <= index) {
        AKRLog(@"Array index out of bounds in [MapCollection removeLocalMapAtIndex:%lu] size = %lu",(unsigned long)index,(unsigned long)self.localItems.count);
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
        AKRLog(@"Array index out of bounds in [MapCollection removeRemoteMapAtIndex:%lu] size = %lu",(unsigned long)index,(unsigned long)self.remoteItems.count);
        return;
    }
    [self.remoteItems removeObjectAtIndex:index];
    [self saveCache];
}

- (void)moveLocalMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex == toIndex)
        return;
    id temp = self.localItems[fromIndex];
    [self.localItems removeObjectAtIndex:fromIndex];
    [self.localItems insertObject:temp atIndex:toIndex];
    [self saveCache];
}

- (void)moveRemoteMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex == toIndex)
        return;
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




#pragma mark - Local Maps

//done on background thread
- (void)refreshLocalMaps
{
    //NOTE: compare file name (without path), because iOS is inconsistent about symbolic links at root of documents path
    NSMutableArray *localMapFileNames = [MapCollection mapFileNamesInDocumentsFolder];

    //remove cache items not in filesystem
    NSMutableIndexSet *indexesOfLocalMapsToRemove = [NSMutableIndexSet new];
    for (NSUInteger i = 0; i < self.localItems.count; i++) {
        Map *map = self.localItems[i];
        //This check will remove remote maps from the local items list
        if (map.isLocal) {
            // A local file is the same as a map if the last path component is the same as the maps (local) tilecache URL
            NSString *name = map.tileCacheURL.lastPathComponent;
            NSUInteger index = (name == nil) ? NSNotFound : [localMapFileNames indexOfObject:name];
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
        if (delegate) {
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
            NSString *name = url.lastPathComponent;
            if (name != nil && [MapCollection collectsURL:url]) {
                [localFileNames addObject:name];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    });
    NSData *data = [NSData dataWithContentsOfURL:url];
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    });
    if (data) {
        id json = [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:nil];
        if ([json isKindOfClass:[NSArray class]])
        {
            maps = [NSMutableArray new];
            NSArray *items = json;
            for (id jsonItem in items) {
                if ([jsonItem isKindOfClass:[NSDictionary class]]) {
                    [maps addObject:jsonItem];
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
    // we need to ignore server maps that are in our local list
    //   - maybe update our memorized details if the server map has better/current details
    // we need to ignore server maps that are in our remote list
    //   - maybe update our memorized details if the server map has better/current details
    // we need to add all other server maps to our remote list
    // we need to remove items in our remote items list that are not found in the server maps

    //Start by assuming we need to add all the remote descriptions (we will remove those that we find)
    NSMutableArray *remotePropertiesToAdd = [NSMutableArray arrayWithArray:serverMaps];

    //Remove memorized local maps from the server list (maybe update details on some local maps)
    NSMutableIndexSet *localMapIndexesToUpdate = [NSMutableIndexSet new];
    for (NSUInteger i = 0; i < self.localItems.count; i++) {
        Map *map = self.localItems[i];
        NSUInteger index = [remotePropertiesToAdd indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [map isEqualToRemoteProperties:(NSDictionary *)obj];
        }];
        if (index != NSNotFound) {
            //If there is a local map that matches, see if it could use some updating
            NSDictionary *remoteMapProperties = remotePropertiesToAdd[index];
            if ([map shouldUpdateToRemoteProperties:remoteMapProperties]) {
                [map updateWithRemoteProperties:remoteMapProperties];
                [localMapIndexesToUpdate addIndex:i];
            }
            [remotePropertiesToAdd removeObjectAtIndex:index];
        }
    }

    //remove memorized maps (in remoteItems) if they are not in serverMaps
    NSMutableIndexSet *remoteMapIndexesToUpdate = [NSMutableIndexSet new];
    NSMutableIndexSet *indexesOfRemoteMapsToRemove = [NSMutableIndexSet new];
    for (NSUInteger i = 0; i < self.remoteItems.count; i++) {
        Map *map = self.remoteItems[i];
        //This check will remove local maps from the remote items list
        if (!map.isLocal) {
            NSUInteger index = [remotePropertiesToAdd indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [map isEqualToRemoteProperties:(NSDictionary *)obj];
            }];
            if (index == NSNotFound) {
                [indexesOfRemoteMapsToRemove addIndex:i];
                [map deleteFromFileSystem];
            } else {
                //update the memorized remote map with the current properties on the server
                NSDictionary *remoteMapProperties = remotePropertiesToAdd[index];
                if ([map shouldUpdateToRemoteProperties:remoteMapProperties]) {
                    [remoteMapIndexesToUpdate addIndex:i];
                    [map updateWithRemoteProperties:remoteMapProperties];
                }
                //If I found a memorized map, then I can ignore it (unless it is a local map
                [remotePropertiesToAdd removeObjectAtIndex:index];
            }
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
            if (0 < remoteMapIndexesToUpdate.count) {
                [delegate collection:self changedRemoteItemsAtIndexes:remoteMapIndexesToUpdate];
            }
            if (0 < localMapIndexesToUpdate.count) {
                [delegate collection:self changedLocalItemsAtIndexes:localMapIndexesToUpdate];
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
        [self.remoteItems removeObjectsAtIndexes:indexesOfRemoteMapsToRemove];
        [self.remoteItems addObjectsFromArray:mapsToAdd];
    }
    //update cache
    if (0 < indexesOfRemoteMapsToRemove.count || 0 < mapsToAdd.count ) {
        if (delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self saveCache];
            });
        } else {
            [self saveCache];
        }
    }
}

@end
