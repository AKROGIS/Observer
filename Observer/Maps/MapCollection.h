//
//  MapCollection.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

//Note that the data model will be changed on the background thread, as changes are made to the collections
//that are referenced by the table view, I must do the insert/delete/change on the mainthread with the call
//to update the UI, otherwise, I will get an internal inconsistency error

#import <Foundation/Foundation.h>
#import "Map.h"
#import "AKRCollectionChanged.h"

@interface MapCollection : NSObject

// Last time that the remote list was refreshed.
@property (nonatomic, strong) NSDate *refreshDate;

//The delegate is sent message to update the UI to stay synced with the model
@property (nonatomic, weak) id<CollectionChanged> delegate;

// This list represents the ordered collection of map files in the filesystem and remote server
// It is a singleton, to avoid synchronization issues between multiple instances
+ (MapCollection *)sharedCollection;

// This will release the memory used by the collection
+ (void)releaseSharedCollection;

// Does this collection manage the provided URL?
+ (BOOL)collectsURL:(NSURL *)url;

// Builds and verifies the ordered lists of remote and local Maps.
// Cache is corrected for changes in the local files system.
// Remote server is queried if it has never been queried before.
// This method does NOT send messsages to the delegate when items are added to the lists.
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

// UITableView DataSource Support
- (NSUInteger) numberOfLocalMaps;
- (NSUInteger) numberOfRemoteMaps;
- (Map *) localMapAtIndex:(NSUInteger)index;
- (Map *) remoteMapAtIndex:(NSUInteger)index;
- (void) insertLocalMap:(Map *)map atIndex:(NSUInteger)index;
- (void) removeLocalMapAtIndex:(NSUInteger)index;
- (void) moveLocalMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void) moveRemoteMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

// Download a Map from the server
- (void)prepareToDownloadMapAtIndex:(NSUInteger)index;

//TODO: is this the best API?
- (void)moveRemoteMapAtIndex:(NSUInteger)fromIndex toLocalMapAtIndex:(NSUInteger)toIndex;

// Cancel a downloading map
- (void)cancelDownloadMapAtIndex:(NSUInteger)index;

// Refresh the list of remote Maps
// Will send message to the delegate as items are added/removed from the local/remote lists
// The completion handler is used only to signal success/failure
- (void) refreshWithCompletionHandler:(void (^)(BOOL success))completionHandler;

//TODO: I don't like making this public, but I need to save the cache after a map changes it's thumbnail url
- (void)synchronize;

@end
