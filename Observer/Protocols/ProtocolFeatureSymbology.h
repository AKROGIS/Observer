//
//  ProtocolFeatureSymbology.h
//  Observer
//
//  Created by Regan Sarwas on 1/30/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <Foundation/Foundation.h>

// This immutable class is a protocol support object and is only created by a protocol feature
// It is highly dependent on the specification for a protocol document.
// property values are undefined (but generally nil) if initialized with non-conformant json
@interface ProtocolFeatureSymbology : NSObject

// If the JSON is not a NSDictionary, then all the properties will be nil
- (instancetype)initWithSymbologyJSON:(id)json version:(NSInteger) version NS_DESIGNATED_INITIALIZER;
- (instancetype) init __attribute__((unavailable("Must use initWithSymbologyJSON:version: instead.")));

@property (strong, nonatomic, readonly) AGSSymbol *agsMarkerSymbol;
@property (strong, nonatomic, readonly) AGSSymbol *agsLineSymbol;

@end
