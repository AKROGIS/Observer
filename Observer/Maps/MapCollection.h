//
//  MapCollection.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AKRTableViewItemCollection.h"
#import "Map.h"
#import "AKRCollectionChanged.h"

@interface MapCollection : NSObject

@property (nonatomic, weak) id<CollectionChanged> delegate;

// This is a singleton - actually a psuedo singleton, it is based on the honor system.
// if you create your own instance with alloc/init then the behaviour is unspecified
+ (MapCollection *)sharedCollection;

+ (void)releaseSharedCollection;
//FIXME: multiple instances will clash when saving state to the cache.
//However, I want to create and destroy the Map list with the view controller to
//avoid keeping the collection in memory if it isn't needed.  making a singleton object
//ensures that it is trapped in memory, unless I create a cleanup method that the VC calls
//when it disappears.
//Not sure the best way to go here.



// Does this collection manage the provided URL?
+ (BOOL) collectsURL:(NSURL *)url;

// builds the list, and current selection from the filesystem and user defaults
// This method does NOT send messsages to the delegate when items are added to the lists.
// so the UI should be updated in the completionHandler;
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

// Opens a file from Mail/Safari (via the App delegate)
// nil return indicates the URL could not be opened or is not valid.
// Will return an existing Map if it already exists in the local collection.
// If the Map exists in the remote list, it will be added to the local list and removed from the remote list.
// Will send messages to the delegate when/if the changes to the model occur.
- (BOOL)openURL:(NSURL *)url;

// UITableView DataSource Support
- (NSUInteger) numberOfLocalMaps;
- (NSUInteger) numberOfRemoteMaps;
- (Map *) localMapAtIndex:(NSUInteger)index;
- (Map *) remoteMapAtIndex:(NSUInteger)index;
- (void) removeLocalMapAtIndex:(NSUInteger)index;
- (void) moveLocalMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void) moveRemoteMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void) setSelectedLocalMap:(NSUInteger)index;
- (Map *)selectedLocalMap;

// Download a Map from the server
- (void)prepareToDownloadMapAtIndex:(NSUInteger)index;
// On success, the delegate will be sent two messages, one to remove the remote item, the other to add the new local item.
// The completion handler is used only to signal success/failure
- (void)downloadMapAtIndex:(NSUInteger)index WithCompletionHandler:(void (^)(BOOL success))completionHandler;
- (void)cancelDownloadMapAtIndex:(NSUInteger)index;

// Refresh the list of remote Maps
// Will send message to the delegate as items are added/removed from the local/remote lists
// The completion handler is used only to signal success/failure
- (void) refreshWithCompletionHandler:(void (^)(BOOL success))completionHandler;

@end
