//
//  MapCollection.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Map.h"
#import "AKRCollectionChanged.h"

@interface MapCollection : NSObject

@property (nonatomic, weak) id<CollectionChanged> delegate;

// This list represents the ordered collection of map files in the filesystem and remote server
// It is a singleton, to avoid synchronization issues between multiple instances
+ (MapCollection *)sharedCollection;

// This will release the memory used by the collection
+ (void)releaseSharedCollection;

// Does this collection manage the provided URL?
+ (BOOL)collectsURL:(NSURL *)url;

// builds/verifies the list, and current selection from the filesystem and user defaults
// This method does NOT send messsages to the delegate when items are added to the lists.
// so the UI should be updated in the completionHandler;
// Warning this must be called from the main thread if it might be called multiple times
// assume completionHandler will be called on a background thread
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
// On success, the delegate will be sent two messages, one to remove the remote item, the other to add the new local item.
// The completion handler is used only to signal success/failure
//- (void)downloadMapAtIndex:(NSUInteger)index WithCompletionHandler:(void (^)(BOOL success))completionHandler;

//TODO: is this the best API?
- (void)moveRemoteMapAtIndex:(NSUInteger)fromIndex toLocalMapAtIndex:(NSUInteger)toIndex;

- (void)cancelDownloadMapAtIndex:(NSUInteger)index;

// Refresh the list of remote Maps
// Will send message to the delegate as items are added/removed from the local/remote lists
// The completion handler is used only to signal success/failure
- (void) refreshWithCompletionHandler:(void (^)(BOOL success))completionHandler;

@property (nonatomic, strong) NSDate *refreshDate;

//TODO: I don't like making this public, but I need to save the cache after a map changes it's thumbnail url
- (void)synchronize;

@end
