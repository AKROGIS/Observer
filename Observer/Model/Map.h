//
//  Map.h
//  Observer
//
//  Created by Regan Sarwas on 8/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AdhocLocations;

@interface Map : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * version;
@property (nonatomic, retain) NSSet *adhocLocations;
@end

@interface Map (CoreDataGeneratedAccessors)

- (void)addAdhocLocationsObject:(AdhocLocations *)value;
- (void)removeAdhocLocationsObject:(AdhocLocations *)value;
- (void)addAdhocLocations:(NSSet *)values;
- (void)removeAdhocLocations:(NSSet *)values;

@end
