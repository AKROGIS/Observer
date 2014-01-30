//
//  ProtocolFeatureSymbology.m
//  Observer
//
//  Created by Regan Sarwas on 1/30/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolFeatureSymbology.h"
#import <ArcGIS/ArcGIS.h>

@implementation ProtocolFeatureSymbology

- (id)initWithSymbologyJSON:(id)json
{
    if (self = [super init]) {
        if ([json isKindOfClass:[NSDictionary class]]) {
            [self defineReadonlyProperties:json];
        }
    }
    return self;
}

// lazy loading doesn't work well when some of the properties may have a valid zero value
// so I just load it all up once when initialized
- (void)defineReadonlyProperties:(NSDictionary *)json
{
    _agsSymbol = [self simpleMarkerSymbolFromColor:json[@"color"] Size:json[@"size"]];
}

- (AGSSimpleMarkerSymbol *)simpleMarkerSymbolFromColor:(id)color Size:(id)size
{
    AGSSimpleMarkerSymbol *symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbol];
    if ([color isKindOfClass:[NSString class]]) {
        UIColor *realColor = [self colorFromHexString:(NSString *)color];
        symbol.color =  realColor;
    }
    if ([size isKindOfClass:[NSNumber class]]) {
        CGFloat realSize = [(NSNumber *)size floatValue];
        symbol.size = CGSizeMake(realSize, realSize);
    }
    return symbol;
}

// Assumes input like "#00FF00" (#RRGGBB).
- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0f green:((rgbValue & 0xFF00) >> 8)/255.0f blue:(rgbValue & 0xFF)/255.0f alpha:1.0f];
}

@end
