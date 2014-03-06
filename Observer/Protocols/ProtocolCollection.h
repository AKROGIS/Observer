//
//  ProtocolCollection.h
//  Observer
//
//  Created by Regan Sarwas on 11/18/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

//Note that the data model will be changed on the background thread, as changes are made to the collections
//that are referenced by the table view, I must do the insert/delete/change on the mainthread with the call
//to update the UI, otherwise, I will get an internal inconsistency error

#import <Foundation/Foundation.h>
#import "SProtocol.h"
#import "AKRCollectionChanged.h"

@interface ProtocolCollection : NSObject

// Last time that the remote list was refreshed.
@property (nonatomic, strong) NSDate *refreshDate;

//The delegate is sent message to update the UI to stay synced with the model
@property (nonatomic, weak) id<CollectionChanged> delegate;

// This list represents the ordered collection of protocol files in the filesystem and remote server
// It is a singleton, to avoid synchronization issues between multiple instances
+ (ProtocolCollection *)sharedCollection;

// This will release the memory used by the collection
+ (void)releaseSharedCollection;

// Does this collection manage the provided URL?
+ (BOOL)collectsURL:(NSURL *)url;

// Builds the ordered lists of remote and local protocols from a saved cache.
// Cache is corrected for changes in the local files system.
// Remote server is queried if it has never been queried before.
// This method does NOT send messsages to the delegate when items are added to the lists.
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

// UITableView DataSource Support
- (NSUInteger) numberOfLocalProtocols;
- (NSUInteger) numberOfRemoteProtocols;
- (SProtocol *) localProtocolAtIndex:(NSUInteger)index;
- (SProtocol *) remoteProtocolAtIndex:(NSUInteger)index;
- (void) insertLocalProtocol:(SProtocol *)protocol atIndex:(NSUInteger)index;
- (void) removeLocalProtocolAtIndex:(NSUInteger)index;
- (void) moveLocalProtocolAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void) moveRemoteProtocolAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

// Download a Protocol from the server
- (void)prepareToDownloadProtocolAtIndex:(NSUInteger)index;

// On success, the delegate will be sent two messages, one to remove the remote item, the other to add the new local item.
// The completion handler is used only to signal success/failure
- (void)downloadProtocolAtIndex:(NSUInteger)index WithCompletionHandler:(void (^)(BOOL success))completionHandler;

// Refresh the list of remote protocols
// Will send message to the delegate as items are added/removed from the local/remote lists
// The completion handler is used only to signal success/failure
- (void)refreshWithCompletionHandler:(void (^)(BOOL success))completionHandler;

@end
