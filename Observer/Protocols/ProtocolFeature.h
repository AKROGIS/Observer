//
//  ProtocolFeature.h
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <Foundation/Foundation.h>
#import "ProtocolFeatureAllowedLocations.h"
#import "ProtocolFeatureSymbology.h"
#import "ProtocolFeatureLabel.h"

// This immutable class is a protocol support object and is only created by a protocol
// It is highly dependent on the specification for a protocol document.
// property values are undefined (but generally nil) if initialized with non-conformant json
@interface ProtocolFeature : NSObject

// If the JSON is not a NSDictionary, then all the properties will be nil
- (instancetype)initWithJSON:(id)json version:(NSInteger) version NS_DESIGNATED_INITIALIZER;
- (instancetype) init __attribute__((unavailable("Must use initWithJSON:version: instead.")));

// The user provided name of this object
@property (strong, nonatomic, readonly) NSString *name;

//Can we observe these features when we are off-transect (i.e. not observing); default is NO
//This is useful for supplemental/optional features (like other species)
@property (nonatomic, readonly) BOOL allowOffTransectObservations;

// What kind of locations are allowed by this feature
@property (strong, nonatomic, readonly) ProtocolFeatureAllowedLocations *allowedLocations;

// How should these features be drawn on the map
@property (strong, nonatomic, readonly) AGSRenderer *pointRenderer;

// How should these features be labeled on the map
@property (strong, nonatomic, readonly) ProtocolFeatureLabel *labelSpec;

// The CoreData attributes used to augment the generic Observation entity
@property (strong, nonatomic, readonly) NSArray *attributes;  //of NSAttributeDescription

// JSON description (in QuickDialog format) for the attribute input/edting form
@property (strong, nonatomic, readonly) NSDictionary *dialogJSON;

// The user selected location method
@property (nonatomic) WaysToLocateFeature preferredLocationMethod;

// The default (default or initial or preferred) location method
@property (nonatomic, readonly) WaysToLocateFeature locationMethod;

// Only for sub classes
- (AGSRenderer *)AGSRendererFromJSON:(NSDictionary *)json;

//Support for Unique ID Attribute
@property (nonatomic, readonly) BOOL hasUniqueId;
@property (strong, nonatomic, readonly) NSNumber *nextUniqueId;
@property (strong, nonatomic, readonly) NSString *uniqueIdName;
- (void)initUniqueId:(NSNumber *)id;

@end
