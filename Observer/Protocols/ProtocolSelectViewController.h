//
//  ProtocolSelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/20/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ProtocolDetailViewController.h"
#import "ProtocolCollection.h"

@interface ProtocolSelectViewController : UITableViewController <CollectionChanged>

@property (strong, nonatomic) ProtocolDetailViewController *detailViewController;
@property (strong, nonatomic) ProtocolCollection *items;
@property (strong, nonatomic) UIPopoverController *popover;
@property (copy, nonatomic) void (^rowSelectedCallback)(NSIndexPath *indexPath);

//Add the protocol to the table view if it isn't there already
- (void) addProtocol:(SProtocol *)protocol;

@end
