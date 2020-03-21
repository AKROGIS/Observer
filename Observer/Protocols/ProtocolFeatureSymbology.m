//
//  ProtocolFeatureSymbology.m
//  Observer
//
//  Created by Regan Sarwas on 1/30/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolFeatureSymbology.h"
#import "AKRLog.h"
#import <ArcGIS/ArcGIS.h>

@implementation ProtocolFeatureSymbology

- (instancetype)initWithSymbologyJSON:(id)json version:(NSInteger) version
{
    self = [super init];
    if (self) {
        if ([json isKindOfClass:[NSDictionary class]]) {
            switch (version) {
                case 1:
                case 2:
                    [self defineReadonlyProperties:json];
                    break;
                default:
                    AKRLog(@"Unsupported version (%ld) of the NPS-Protocol-Specification", (long)version);
                    break;
            }
        }
    }
    return self;
}

// lazy loading doesn't work well when some of the properties may have a valid zero value
// so I just load it all up once when initialized
- (void)defineReadonlyProperties:(NSDictionary *)json
{
    _agsMarkerSymbol = [self simpleMarkerSymbolFromColor:json[@"color"] Size:json[@"size"]];
    _agsLineSymbol = [self simpleLineSymbolFromColor:json[@"color"] Size:json[@"size"]];
}

- (AGSSimpleMarkerSymbol *)simpleMarkerSymbolFromColor:(id)color Size:(id)size
{
    UIColor *markerColor = [UIColor blackColor];
    if ([color isKindOfClass:[NSString class]]) {
        UIColor *maybeColor = [self colorFromHexString:(NSString *)color];
        if (maybeColor) {
            markerColor = maybeColor;
        }
    }
    CGFloat markerSize = 8.0;
    if ([size isKindOfClass:[NSNumber class]]) {
        markerSize = (CGFloat)((NSNumber *)size).doubleValue;
    }
    AGSSimpleMarkerSymbol *symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithStyle:AGSSimpleMarkerSymbolStyleCircle color:markerColor size:markerSize];

    return symbol;
}

- (AGSSimpleLineSymbol *)simpleLineSymbolFromColor:(id)color Size:(id)size
{
    UIColor *lineColor = [UIColor blackColor];
    if ([color isKindOfClass:[NSString class]]) {
        UIColor *maybeColor = [self colorFromHexString:(NSString *)color];
        if (maybeColor) {
            lineColor = maybeColor;
        }
    }
    CGFloat width = 1.0;
    if ([size isKindOfClass:[NSNumber class]]) {
        width = (CGFloat)((NSNumber *)size).doubleValue;
    }
    AGSSimpleLineSymbol *symbol = [AGSSimpleLineSymbol simpleLineSymbolWithStyle:AGSSimpleLineSymbolStyleSolid color:lineColor width:width];
    return symbol;
}

// Assumes input like "#00FF00" (#RRGGBB).
- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    if ([hexString characterAtIndex:0] != '#') {
        return nil;
    }
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    scanner.scanLocation = 1; // bypass '#' character
    if ([scanner scanHexInt:&rgbValue]) {
        CGFloat max = 255.0;
        return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/max green:((rgbValue & 0xFF00) >> 8)/max blue:(rgbValue & 0xFF)/max alpha:1.0];
    } else {
        return nil;
    }
}

@end
