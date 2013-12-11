//
//  CollectionChanged.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CollectionChanged <NSObject>

- (void) collection:(id)collection addedLocalItemsAtIndexes:(NSIndexSet *)indexSet;
- (void) collection:(id)collection addedRemoteItemsAtIndexes:(NSIndexSet *)indexSet;
- (void) collection:(id)collection removedLocalItemsAtIndexes:(NSIndexSet *)indexSet;
- (void) collection:(id)collection removedRemoteItemsAtIndexes:(NSIndexSet *)indexSet;
- (void) collection:(id)collection changedLocalItemsAtIndexes:(NSIndexSet *)indexSet;
- (void) collection:(id)collection changedRemoteItemsAtIndexes:(NSIndexSet *)indexSet;

@end

