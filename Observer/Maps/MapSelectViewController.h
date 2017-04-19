//
//  MapSelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Map.h"
#import "AKRCollectionChanged.h"

@interface MapSelectViewController : UITableViewController <CollectionChanged>

// A block to execute when a map is selected.
// This will be called even if the user re-selects the current map
// This will NOT be called if the user deletes the current map.
@property (copy, nonatomic) void (^mapSelectedAction)(Map *map);

// A block to execute when a map is deleted; map is the deleted map
@property (nonatomic, copy) void (^mapDeletedAction)(Map *map);

// Add the map to the TableView
// Used when a map was obtained external to the VC
// Also ensures that the collection and the caller are refering to the same object
- (void) addMap:(Map *)map;

@end
