//
//  ProtocolFeatureLabel.h
//  Observer
//
//  Created by Regan Sarwas on 6/10/16.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

// This immutable class is a protocol support object and is only created by a protocol feature
// It is highly dependent on the specification for a protocol document.
// property values are undefined (but generally nil) if initialized with non-conformant json
@interface ProtocolFeatureLabel: NSObject

// If the JSON is not a NSDictionary, then all the properties will be nil
- (id)initWithLabelJSON:(id)json version:(NSInteger) version;
- (id) init __attribute__((unavailable("Must initWithLabelJSON:version: instead.")));

@property (strong, nonatomic, readonly) NSString *field;
@property (strong, nonatomic, readonly) UIColor *color;
@property (strong, nonatomic, readonly) NSDictionary *symbolJSON;
@property (nonatomic, readonly) BOOL hasColor;
@property (nonatomic, readonly) BOOL hasSymbol;

@end
