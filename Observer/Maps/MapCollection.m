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

@interface MapCollection()
@property (nonatomic, strong) NSMutableArray *localItems;  // of Map
@property (nonatomic, strong) NSMutableArray *remoteItems; // of Map
@property (nonatomic) NSUInteger selectedLocalIndex;
@property (nonatomic, strong) NSURL *documentsDirectory;
@property (nonatomic, strong) NSURL *mapDirectory;
@property (nonatomic, strong) NSURL *inboxDirectory;
@property (nonatomic, strong) NSURL *cacheFile;
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
        _documentsDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    }
    return _documentsDirectory;
}

- (NSURL *)mapDirectory
{
    if (!_mapDirectory) {
        _mapDirectory = [self.documentsDirectory URLByAppendingPathComponent:MAP_DIR];
        if(![[NSFileManager defaultManager] fileExistsAtPath:[_mapDirectory path]]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:[_mapDirectory path]
                                      withIntermediateDirectories:YES attributes:nil error:nil];
            //TODO: set this directory to not backup
        }
    }
    return _mapDirectory;
}

- (NSURL *)inboxDirectory
{
    if (!_inboxDirectory) {
        _inboxDirectory = [self.documentsDirectory URLByAppendingPathComponent:@"Inbox"];
    }
    return _inboxDirectory;
}

- (NSURL *)cacheFile
{
    if (!_cacheFile) {
        _cacheFile = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask][0];
        _cacheFile = [_cacheFile URLByAppendingPathComponent:@"map_list.cache"];
    }
    return _cacheFile;
}


#pragma mark - TableView Data Soource Support

- (Map *)localMapAtIndex:(NSUInteger)index
{
    //if (self.localItems.count <= index) return; //safety check
    return self.localItems[index];
}

- (Map *)remoteMapAtIndex:(NSUInteger)index
{
    //if (self.remoteItems.count <= index) return; //safety check
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
    //if (self.localItems.count <= index) return; //safety check
    Map *item = [self localMapAtIndex:index];
    [[NSFileManager defaultManager] removeItemAtURL:item.url error:nil];
    [self.localItems removeObjectAtIndex:index];
    [self saveCache];
    if (index < self.selectedLocalIndex) {
        self.selectedLocalIndex = self.selectedLocalIndex - 1;
    }
}

-(void)moveLocalMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    //if (self.localItems.count <= fromIndex || self.localItems.count <= toIndex) return;  //safety check
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
    //if (self.localItems.count <= fromIndex || self.localItems.count <= toIndex) return;  //safety check
    if (fromIndex == toIndex)
        return;
    id temp = self.remoteItems[fromIndex];
    [self.remoteItems removeObjectAtIndex:fromIndex];
    [self.remoteItems insertObject:temp atIndex:toIndex];
    [self saveCache];
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


- (void)openWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    if (self.isLoaded) {
        if (completionHandler) completionHandler(YES);
    } else {
        dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
            //temporarily remove the delegate so that updates are not sent for the bulk updates before the UI might be ready
            //  currently unnecessary, since open is only called when the delegate is nil;
            id savedDelegate = self.delegate;
            self.delegate = nil;
            [self loadCache];
            BOOL success = [self refreshLocalMaps];
            [self saveCache];
            self.delegate = savedDelegate;
            self.isLoaded = YES;
            if (completionHandler) {
                completionHandler(success);
            }
        });
    }
}


- (BOOL)openURL:(NSURL *)url
{
    //FIXME: SProtocol returns the protocol, Survey returns BOOL, which should I use?
    return ![self openURL:url saveCache:YES];
}


- (void)refreshWithCompletionHandler:(void (^)(BOOL))completionHandler;
{
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
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
    //if (self.remoteItems.count <= index) return; //safety check
    [self.remoteItems[index] prepareToDownload];
}

- (void)cancelDownloadMapAtIndex:(NSUInteger)index
{
    
}

- (void)downloadMapAtIndex:(NSUInteger)index WithCompletionHandler:(void (^)(BOOL success))completionHandler
{
    //if (self.remoteItems.count <= index) return; //safety check
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
        Map *map = [self remoteMapAtIndex:index];
        NSURL *newUrl = [self.mapDirectory URLByAppendingPathComponent:map.url.lastPathComponent];
        newUrl = [newUrl URLByUniquingPath];
        BOOL success = [map downloadToURL:newUrl];
        if (success) {
            if (self.delegate) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.remoteItems removeObjectAtIndex:index];
                    [self.delegate collection:self removedRemoteItemsAtIndexes:[NSIndexSet indexSetWithIndex:index]];
                    [self.localItems insertObject:map atIndex:0];
                    [self.delegate collection:self addedLocalItemsAtIndexes:[NSIndexSet indexSetWithIndex:0]];
                    [self saveCache];
                });
            } else {
                [self.remoteItems removeObjectAtIndex:index];
                [self.localItems insertObject:map atIndex:0];
                [self saveCache];
            }
        }
        if (completionHandler) {
            completionHandler(success);
        }
    });
}



#pragma mark - private methods

//TODO: - consider NSDefaults as it does memory mapping and defered writes
//       this also make the class a singleton object

//done on background thread
- (void)loadCache
{
    NSArray *plist = [NSArray arrayWithContentsOfURL:self.cacheFile];
    for (id obj in plist) {
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


//must be called by the thread that changes the model, after changes are complete.
//because of the enumeration of the model, it cannot be called while the model might be changed.
- (void)saveCache
{
    //dispatching the creation of the archive data to a background thread could result in an exception
    //if the UI thread then changed the model while it is being enumerated
    NSMutableArray *plist = [NSMutableArray new];
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
    NSURL *newUrl = [self.mapDirectory URLByAppendingPathComponent:url.lastPathComponent];
    newUrl = [newUrl URLByUniquingPath];
    NSError *error = nil;
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:newUrl error:&error];
    if (error) {
        NSLog(@"MapCollection.openURL: Unable to copy %@ to %@; error: %@",url, newUrl, error);
        return nil;
    }
    Map *map = [[Map alloc] initWithURL:newUrl];
    if (!map.tileCache) {
        NSLog(@"data in %@ was not a valid map object",url.lastPathComponent);
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
        NSLog(@"We already have the map in %@.  Ignoring the duplicate.",url.lastPathComponent);
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
- (BOOL)refreshLocalMaps;
{
    [self moveIncomingDocuments];
    [self syncWithFileSystem];
    return YES;
}


//done on background thread
- (void) moveIncomingDocuments
{
    //If a file is added to the inbox, then the mapcollection was created to add the inbox object, it will not be there when openURL is called.
    //OpenURL returns a map whcih can't be found if the URL is gone. therefore we cannot add Inbox items on open.
    //for (NSURL *directory in @[self.inboxDirectory, self.documentsDirectory]) {
    for (NSURL *directory in @[self.documentsDirectory]) {
        NSError *error = nil;
        NSArray *array = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtURL:directory
                          includingPropertiesForKeys:nil
                          options:(NSDirectoryEnumerationSkipsHiddenFiles)
                          error:&error];
        if (array == nil) {
            NSLog(@"Unable to enumerate %@: %@",[directory lastPathComponent], error.localizedDescription);
        } else {
            for (NSURL *doc in array) {
                if ([doc.pathExtension isEqualToString:MAP_EXT]) {
                    [self openURL:doc saveCache:NO];
                }
            }
        }
    }
}

//done on background thread
- (void)syncWithFileSystem
{
    //urls in the maps directory
    NSMutableArray *urls = [NSMutableArray arrayWithArray:[[NSFileManager defaultManager]
                                                           contentsOfDirectoryAtURL:self.mapDirectory
                                                           includingPropertiesForKeys:nil
                                                           options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                           error:nil]];
    //remove cache items not in filesystem
    NSMutableIndexSet *itemsToRemove = [NSMutableIndexSet new];
    for (int i = 0; i < self.localItems.count; i++) {
        Map *p = self.localItems[i];
        if (p.isLocal) {
            NSUInteger index = [urls indexOfObject:p.url];
            if (index == NSNotFound) {
                [itemsToRemove addIndex:i];
            } else {
                [urls removeObjectAtIndex:index];
            }
        }
    }

    //add filesystem urls not in cache
    NSMutableArray *mapsToAdd = [NSMutableArray new];
    for (NSURL *url in urls) {
        Map *map = [[Map alloc] initWithURL:url];
        if (!map.tileCache) {
            NSLog(@"data at %@ was not a valid map object",url);
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
        [mapsToAdd addObject:map];
    }

    //update lists and UI synchronosly on UI thread if there is a delegate
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


//done on background thread
- (BOOL)refreshRemoteMaps;
{
    //FIXME: get URL from settings
    NSURL *url = [NSURL URLWithString:@"file:///Users/regan/Downloads/maplist.json"];
    //NSURL *url = [NSURL URLWithString:@"http://akrgis.nps.gov/observer/maps/maplist.json"];
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
    for (int i = 0; i < self.remoteItems.count; i++) {
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
                self.remoteItems[[key integerValue]] = [mapsToUpdate objectForKey:key];
                [self.delegate collection:self changedRemoteItemsAtIndexes:[NSIndexSet indexSetWithIndex:[key integerValue]]];
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
            self.remoteItems[[key integerValue]] = [mapsToUpdate objectForKey:key];
        }
        [self.remoteItems removeObjectsAtIndexes:itemsToRemove];
        [self.remoteItems addObjectsFromArray:mapsToAdd];
    }
    return modelChanged;
}

- (void) checkAndFixSelectedIndex
{
    if (self.localItems.count <= self.selectedLocalIndex) {
        self.selectedLocalIndex = (self.localItems.count == 0) ? 0 : self.localItems.count - 1;
    }
}


@end
