//
//  ProtocolCollection.h
//  Observer
//
//  Created by Regan Sarwas on 11/18/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

@class ProtocolCollection;

//Note that the data model will be changed on the background thread, as changes are made to the collections
//that are referenced by the table view, I must do the insert/delete/change on the mainthread with the call
//to update the UI, otherwise, I will get an internal inconsistency error

#import <Foundation/Foundation.h>
#import "SProtocol.h"
#import "AKRCollectionChanged.h"

#define PROTOCOL_EXT @"obsprot"
#define PROTOCOL_DIR @"protocols"

@interface ProtocolCollection : NSObject

@property (nonatomic, weak) id<CollectionChanged> delegate;

// This is a singleton - actually a psuedo singleton, it is based on the honor system.
// if you create your own instance with alloc/init then the behaviour is unspecified
+ (ProtocolCollection *)sharedCollection;

+ (void)releaseSharedCollection;
//TODO: this is a memory optimization that needs to be validated and tested
//multiple instances will clash when saving state to the cache.
//However, I want to create and destroy the protocol list with the view controller to
//avoid keeping the collection in memory if it isn't needed.  making a singleton object
//ensures that it is trapped in memory, unless I create a cleanup method that the VC calls
//when it disappears. - Not sure the best way to go here.


// Does this collection manage the provided URL?
+ (BOOL) collectsURL:(NSURL *)url;

// builds the list, and current selection from the filesystem and user defaults
// This method does NOT send messsages to the delegate when items are added to the lists.
// so the UI should be updated in the completionHandler;
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

// Opens a file from Mail/Safari (via the App delegate)
// nil return indicates the URL could not be opened or is not valid.
// Will return an existing protocol if it already exists in the local collection.
// If the protocol exists in the remote list, it will be added to the local list and removed from the remote list.
// Will send messages to the delegate when/if the changes to the model occur.
- (SProtocol *)openURL:(NSURL *)url;

// UITableView DataSource Support
- (NSUInteger) numberOfLocalProtocols;
- (NSUInteger) numberOfRemoteProtocols;
- (SProtocol *) localProtocolAtIndex:(NSUInteger)index;
- (SProtocol *) remoteProtocolAtIndex:(NSUInteger)index;
- (void) removeLocalProtocolAtIndex:(NSUInteger)index;
- (void) moveLocalProtocolAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void) moveRemoteProtocolAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void) setSelectedLocalProtocol:(NSUInteger)index;
- (SProtocol *)selectedLocalProtocol;

// Download a Protocol from the server
- (void)prepareToDownloadProtocolAtIndex:(NSUInteger)index;
// On success, the delegate will be sent two messages, one to remove the remote item, the other to add the new local item.
// The completion handler is used only to signal success/failure
- (void)downloadProtocolAtIndex:(NSUInteger)index WithCompletionHandler:(void (^)(BOOL success))completionHandler;

// Refresh the list of remote protocols
// Will send message to the delegate as items are added/removed from the local/remote lists
// The completion handler is used only to signal success/failure
- (void) refreshWithCompletionHandler:(void (^)(BOOL success))completionHandler;

@property (nonatomic, strong) NSDate *refreshDate;

@end
