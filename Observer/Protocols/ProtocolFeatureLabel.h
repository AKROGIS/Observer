//
//  ProtocolFeatureLabel.h
//  Observer
//
//  Created by Regan Sarwas on 6/10/16.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// This immutable class is a protocol support object and is only created by a protocol feature
// It is highly dependent on the specification for a protocol document.
// property values are undefined (but generally nil) if initialized with non-conformant json
@interface ProtocolFeatureLabel: NSObject

// If the JSON is not a NSDictionary, then all the properties will be nil
- (instancetype)initWithLabelJSON:(id)json version:(NSInteger) version NS_DESIGNATED_INITIALIZER;
- (instancetype) init __attribute__((unavailable("Must initWithLabelJSON:version: instead.")));


//if field is not provided, or not a valid attribute, then there will be no label.
@property (strong, nonatomic, readonly) NSString *field;

// Simple label symbology - label lower left justified to point, with offset for 15 point round marker
// color is optional, default is white
@property (strong, nonatomic, readonly) UIColor *color;
// size is optional, default is 14 points
@property (strong, nonatomic, readonly) NSNumber *size;

// Full ESRI label symbology, see REST API for details; however not all features appear to be supported in iOS
// if symbol is invalid JSON, then the symbol is ignored (i.e. nil, or not provided)
// if symbol is provided, size and color is ignored.
@property (strong, nonatomic, readonly) NSDictionary *symbolJSON;

// convenience properties
@property (nonatomic, readonly) BOOL hasSymbol;

@end
