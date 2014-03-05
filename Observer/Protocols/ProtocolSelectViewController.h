//
//  ProtocolSelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/20/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SProtocol.h"
#import "AKRCollectionChanged.h"

@interface ProtocolSelectViewController : UITableViewController <CollectionChanged>

// A block to execute when a protocol is selected.
@property (copy, nonatomic) void (^protocolSelectedAction)(SProtocol *protocol);

// Add the protocol to the TableView
// Used when a protocol was obtained external to the VC
// Also ensures that the collection and the caller are refering to the same object
- (void) addProtocol:(SProtocol *)protocol;

@end
