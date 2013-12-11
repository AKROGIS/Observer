//
//  MapReference.h
//  Observer
//
//  Created by Regan Sarwas on 12/11/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AdhocLocation;

@interface MapReference : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * version;
@property (nonatomic, retain) NSSet *adhocLocations;
@end

@interface MapReference (CoreDataGeneratedAccessors)

- (void)addAdhocLocationsObject:(AdhocLocation *)value;
- (void)removeAdhocLocationsObject:(AdhocLocation *)value;
- (void)addAdhocLocations:(NSSet *)values;
- (void)removeAdhocLocations:(NSSet *)values;

@end
