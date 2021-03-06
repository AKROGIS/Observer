//
//  ProtocolCollection.m
//  Observer
//
//  Created by Regan Sarwas on 11/18/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

/*
 The big problems:
 1) multiple threads could inconsistently mutate the local or remote lists, i.e. the user deletes an item, while it is being refreshed.
 2) add/remove/updates to the table view must be synced with changes to the model, therefore, the model must be changed on the UI
 thread in concert with the updates to the table view.  (optionally you can do a reload, which does not check consistency).
 for a background task that dispatches these changes to the UI thread, it must syncronize the save cache operation until all the UI
 updates are done (otherwise it is saving an incomlete picture, and risks doing an enumeration of the list while it is mutatuing (crash!)
 
 various solutions:
 1) create a private serial queue.  dispatch_async tasks onto the queue, the queue will execute each task in order.
 the tasks will dispatch sync onto the main queue, with the net effect that each operation runs in turn on the main
 queue, ensuring ordered operations, and no conflicting access to critical resources (i.e. my mutable lists)
 2) for the refresh and the bulk load, skip incremental updates, and do a bulk reload in the callback.  Any UI
 operation that might change the lists must be disabled between the call and the callback.
 3) use locks for all changes and enumerations (all reads?) of the item lists. - complicated and slow
 4) do all changes on the UI thread, and make a copy from the UI for all background tasks, then syncronize updates on the UI thread.
 This doesn't sound like it will work.
 
 */


#import "ProtocolCollection.h"
#import "NSArray+map.h"
#import "NSURL+unique.h"
#import "Settings.h"
#import "AKRLog.h"

@interface ProtocolCollection()
@property (nonatomic, strong) NSMutableArray *localItems;  // of SProtocol
@property (nonatomic, strong) NSMutableArray *remoteItems; // of SProtocol
@end

@implementation ProtocolCollection

#pragma mark - singleton

static ProtocolCollection *_sharedCollection = nil;
static BOOL _isLoaded = NO;

+ (ProtocolCollection *) sharedCollection {
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




#pragma mark - public methods

+ (BOOL)collectsURL:(NSURL *)url
{
    return [url.pathExtension isEqualToString:PROTOCOL_EXT];
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
                dispatch_async(dispatch_queue_create("gov.nps.akr.observer.protocolcollection.open", DISPATCH_QUEUE_SERIAL), ^{
                    //This task is serial with the task that will clear isLoading, so it will not run until loading is done;
                    if (completionHandler) {
                        completionHandler(self.localItems != nil  && self.remoteItems != nil);
                    }
                });
            } else {
                isLoading = YES;
                dispatch_async(dispatch_queue_create("gov.nps.akr.observer.protocolcollection.open", DISPATCH_QUEUE_SERIAL), ^{
                    [self loadCache];
                    [self refreshLocalProtocols];
                    if (!self.refreshDate) {
                        [self refreshRemoteProtocols];
                        self.refreshDate = [NSDate date];
                    }
                    _isLoaded = YES;
                    isLoading = NO;
                    if (completionHandler) {
                        completionHandler(self.localItems != nil  && self.remoteItems != nil);
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
        [self refreshLocalProtocols];
        BOOL success = [self refreshRemoteProtocols];
        if (completionHandler) {
            completionHandler(success);
        }
    });
}




#pragma mark - TableView Data Soource Support

-(NSUInteger)numberOfLocalProtocols
{
    return self.localItems.count;
}

-(NSUInteger)numberOfRemoteProtocols
{
    return self.remoteItems.count;
}

- (SProtocol *)localProtocolAtIndex:(NSUInteger)index
{
    if (self.localItems.count <= index) {
        AKRLog(@"Array index out of bounds in [ProtocolCollection localProtocolAtIndex:%lu]; size = %lu",(unsigned long)index,(unsigned long)self.localItems.count);
        return nil;
    }
    return self.localItems[index];
}

- (SProtocol *)remoteProtocolAtIndex:(NSUInteger)index
{
    if (self.remoteItems.count <= index) {
        AKRLog(@"Array index out of bounds in [ProtocolCollection remoteProtocolAtIndex:%lu]; size = %lu",(unsigned long)index,(unsigned long)self.remoteItems.count);
        return nil;
    }
    return self.remoteItems[index];
}

- (void)insertLocalProtocol:(SProtocol *)protocol atIndex:(NSUInteger)index
{
    [self.localItems insertObject:protocol atIndex:index];
    [self saveCache];
}

-(void)removeLocalProtocolAtIndex:(NSUInteger)index
{
    if (self.localItems.count <= index) {
        AKRLog(@"Array index out of bounds in [ProtocolCollection removeLocalProtocolAtIndex:%lu] size = %lu",(unsigned long)index,(unsigned long)self.localItems.count);
        return;
    }
    SProtocol *item = [self localProtocolAtIndex:index];
    [[NSFileManager defaultManager] removeItemAtURL:item.url error:nil];
    [self.localItems removeObjectAtIndex:index];
    [self saveCache];
}

- (void)removeRemoteProtocolAtIndex:(NSUInteger)index
{
    if (self.remoteItems.count <= index) {
        AKRLog(@"Array index out of bounds in [ProtocolCollection removeRemoteProtocolAtIndex:%lu] size = %lu",(unsigned long)index,(unsigned long)self.remoteItems.count);
        return;
    }
    [self.remoteItems removeObjectAtIndex:index];
    [self saveCache];
}

-(void)moveLocalProtocolAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex == toIndex)
        return;
    id temp = self.localItems[fromIndex];
    [self.localItems removeObjectAtIndex:fromIndex];
    [self.localItems insertObject:temp atIndex:toIndex];
    [self saveCache];
}

-(void)moveRemoteProtocolAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
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


//TODO: #39 consider NSDefaults as it does memory mapping and defered writes
//       this also make the class a singleton object

+ (NSURL *)cacheFile
{
    static NSURL *_cacheFile = nil;
    {
        if (!_cacheFile) {
            _cacheFile = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
            _cacheFile = [_cacheFile URLByAppendingPathComponent:@"protocol_list.cache"];
        }
        return _cacheFile;
    }
}

//done on background thread
- (void)loadCache
{
    NSArray *plist = [NSArray arrayWithContentsOfURL:[ProtocolCollection cacheFile]];
    for (id obj in plist) {
        if ([obj isKindOfClass:[NSDate class]]) {
            self.refreshDate = obj;
        }
        if ([obj isKindOfClass:[NSData class]]) {
            id protocol = [NSKeyedUnarchiver unarchiveObjectWithData:obj];
            if ([protocol isKindOfClass:[SProtocol class]]) {
                if (((SProtocol *)protocol).isLocal) {
                    [self.localItems addObject:protocol];
                } else {
                    [self.remoteItems addObject:protocol];
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
    for (SProtocol *protocol in self.localItems) {
        [plist addObject:[NSKeyedArchiver archivedDataWithRootObject:protocol]];
    }
    for (SProtocol *protocol in self.remoteItems) {
        [plist addObject:[NSKeyedArchiver archivedDataWithRootObject:protocol]];
    }
    //File save can be safely done on a background thread.
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer",DISPATCH_QUEUE_CONCURRENT), ^{
        [plist writeToURL:[ProtocolCollection cacheFile] atomically:YES];
    });
}




#pragma mark - Local Protocols

//done on background thread
- (void)refreshLocalProtocols
{
    //NOTE: compare file name (without path), because iOS is inconsistent about symbolic links at root of documents path
    NSMutableArray *localProtocolFileNames = [ProtocolCollection protocolFileNamesInDocumentsFolder];

    //remove cache items not in filesystem
    NSMutableIndexSet *itemsToRemove = [NSMutableIndexSet new];
    for (uint i = 0; i < self.localItems.count; i++) {
        SProtocol *p = self.localItems[i];
        if (p.isLocal) {
            NSString *name = p.url.lastPathComponent;
            NSUInteger index = (name == nil) ? NSNotFound : [localProtocolFileNames indexOfObject:name];
            if (index == NSNotFound || !p.isValid) {
                [itemsToRemove addIndex:i];
            } else {
                [localProtocolFileNames removeObjectAtIndex:index];
            }
        }
    }

    //add valid protocols in the filesystem that are not in cache
    NSMutableArray *protocolsToAdd = [NSMutableArray new];
    for (NSString *localProtocolFileName in localProtocolFileNames) {
        NSURL *protocolUrl = [[ProtocolCollection documentsDirectory] URLByAppendingPathComponent:localProtocolFileName];
        SProtocol *protocol = [[SProtocol alloc] initWithURL:protocolUrl];
        if (protocol.isValid) {
            [protocolsToAdd addObject:protocol];
        } else {
            AKRLog(@"Data in %@ was not a valid protocol object. It is being deleted.",localProtocolFileName);
            [[NSFileManager defaultManager] removeItemAtURL:protocolUrl error:nil];
        }
    }

    //update lists and UI synchronosly on UI thread if there is a delegate
    id<CollectionChanged> delegate = self.delegate;
    if (delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (0 < itemsToRemove.count) {
                [self.localItems removeObjectsAtIndexes:itemsToRemove];
                [delegate collection:self removedLocalItemsAtIndexes:itemsToRemove];
            }
            if (0 < protocolsToAdd.count) {
                NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.localItems.count, protocolsToAdd.count)];
                [self.localItems addObjectsFromArray:protocolsToAdd];
                [delegate collection:self addedLocalItemsAtIndexes:indexes];
            }
        });
    } else {
        [self.localItems removeObjectsAtIndexes:itemsToRemove];
        [self.localItems addObjectsFromArray:protocolsToAdd];
    }
    //update cache
    if (0 < itemsToRemove.count || 0 < protocolsToAdd.count) {
        if (delegate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self saveCache];
            });
        } else {
            [self saveCache];
        }
    }
}

+ (NSMutableArray *) /* of NSString */  protocolFileNamesInDocumentsFolder
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
            if (name != nil && [ProtocolCollection collectsURL:url]) {
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
        _documentsDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    }
    return _documentsDirectory;
}




#pragma mark - Remote Protocols

//done on background thread
- (BOOL)refreshRemoteProtocols
{
    NSURL *url = [Settings manager].urlForProtocols;
    NSMutableArray *serverProtocols = [ProtocolCollection fetchProtocolListFromURL:url];
    if (serverProtocols) {
        [self syncCacheWithServerProtocols:serverProtocols];
        return YES;
    }
    return NO;
}

//done on background thread
+ (NSMutableArray *)fetchProtocolListFromURL:(NSURL *)url
{
    NSMutableArray *protocols = nil;
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
            protocols = [NSMutableArray new];
            NSArray *items = json;
            for (id jsonItem in items) {
                if ([jsonItem isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *item = jsonItem;
                    NSString *path = item[@"url"];
                    NSURL *protocolUrl = (path == nil) ? nil : [NSURL URLWithString:path];
                    SProtocol *protocol = [[SProtocol alloc] initWithURL:protocolUrl
                                                                   title:item[@"name"]
                                                                 version:item[@"version"]
                                                                    date:item[@"date"]];
                    if (protocol) {
                        [protocols addObject:protocol];
                    }
                }
            }
        }
    }
    return protocols;
}

//done on background thread
-  (void)syncCacheWithServerProtocols:(NSMutableArray *)serverProtocols
{
    // return value of YES means changes were made and the caller should update the cache.
    // we need to remove cached items not on the server,
    // we need to add items on the server not in the cache,
    // Do not add server items that match local items in the cache.
    // a cached item (on the server) might have an updated URL

    BOOL modelChanged = NO;

    //do not change the list while enumerating
    NSMutableDictionary *protocolsToUpdate = [NSMutableDictionary new];

    //remove protocols in remoteItems not in serverProtocols
    NSMutableIndexSet *itemsToRemove = [NSMutableIndexSet new];
    for (uint i = 0; i < self.remoteItems.count; i++) {
        SProtocol *p = self.remoteItems[i];
        if (!p.isLocal) {
            NSUInteger index = [serverProtocols  indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [p isEqualToProtocol:obj];
            }];
            if (index == NSNotFound) {
                [itemsToRemove addIndex:i];
                modelChanged = YES;
            } else {
                //update the url of cached server objects
                SProtocol *serverProtocol = serverProtocols[index];
                if (![p.url isEqual:serverProtocol.url]) {
                    protocolsToUpdate[@(i)] = serverProtocol;
                    modelChanged = YES;
                }
                [serverProtocols removeObjectAtIndex:index];
            }
        }
    }
    //add server protocols not in cache (local or server)
    NSMutableArray *protocolsToAdd = [NSMutableArray new];
    for (SProtocol *protocol in serverProtocols) {
        NSUInteger localIndex = [self.localItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [protocol isEqualToProtocol:obj];
        }];
        NSUInteger remoteIndex = [self.remoteItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [protocol isEqualToProtocol:obj];
        }];
        if (localIndex == NSNotFound && remoteIndex == NSNotFound) {
            [protocolsToAdd addObject:protocol];
            modelChanged = YES;
        }
    }
    //update lists and UI synchronosly on UI thread if there is a delegate
    id<CollectionChanged> delegate = self.delegate;
    if (delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (id key in protocolsToUpdate.allKeys) {
                id protocol = protocolsToUpdate[key];
                self.remoteItems[[key unsignedIntegerValue]] = protocol;
                [delegate collection:self changedRemoteItemsAtIndexes:[NSIndexSet indexSetWithIndex:[key unsignedIntegerValue]]];
            }
            if (0 < itemsToRemove.count) {
                [self.remoteItems removeObjectsAtIndexes:itemsToRemove];
                [delegate collection:self removedRemoteItemsAtIndexes:itemsToRemove];
            }
            if (0 < protocolsToAdd.count) {
                NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.remoteItems.count, protocolsToAdd.count)];
                [self.remoteItems addObjectsFromArray:protocolsToAdd];
                [delegate collection:self addedRemoteItemsAtIndexes:indexes];
            }
        });
    } else {
        for (id key in protocolsToUpdate.allKeys) {
            id protocol = protocolsToUpdate[key];
            self.remoteItems[[key unsignedIntegerValue]] = protocol;
        }
        [self.remoteItems removeObjectsAtIndexes:itemsToRemove];
        [self.remoteItems addObjectsFromArray:protocolsToAdd];
    }
    //update cache
    if (modelChanged) {
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
