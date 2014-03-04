//
//  ProtocolSelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/20/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ProtocolDetailViewController.h"
#import "AKRCollectionChanged.h"
#import "SProtocol.h"

@interface ProtocolSelectViewController : UITableViewController <CollectionChanged>

@property (strong, nonatomic) ProtocolDetailViewController *detailViewController;
@property (strong, nonatomic) UIPopoverController *popover;
@property (copy, nonatomic) void (^protocolSelectedCallback)(SProtocol *protocol);

//Add the protocol to the table view if it isn't there already
- (void) addProtocol:(SProtocol *)protocol;

@end
