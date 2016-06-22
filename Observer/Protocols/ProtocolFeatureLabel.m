//
//  ProtocolFeatureLabel.m
//  Observer
//
//  Created by Regan Sarwas on 6/10/16.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import "ProtocolFeatureLabel.h"

@implementation ProtocolFeatureLabel

- (id)initWithLabelJSON:(id)json version:(NSInteger) version
{
    if (self = [super init]) {
        if ([json isKindOfClass:[NSDictionary class]]) {
            switch (version) {
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
    id value = json[@"field"];
    if ([value isKindOfClass:[NSString class]]) {
        _field = value;
    }

    _color = [UIColor whiteColor];
    value = json[@"color"];
    if ([value isKindOfClass:[NSString class]]) {
        _color = [self colorFromHexString:value];
    }
    
    _size = [NSNumber numberWithInt:14];
    value = json[@"size"];
    if ([value isKindOfClass:[NSNumber class]]) {
        _size = value;
    }
    
    value = json[@"symbol"];
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *symbolJSON = (NSDictionary *)value;
        id data = symbolJSON[@"type"];
        if ([data isKindOfClass:[NSString class]]) {
            NSString *key = (NSString *)data;
            if ([key isEqualToString:@"esriTS"])
            {
                _symbolJSON = symbolJSON;
                _hasSymbol = YES;
            }
        }
    }
}

// Assumes input like "#00FF00" (#RRGGBB).
- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    if ([hexString characterAtIndex:0] != '#') {
        return nil;
    }
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    if ([scanner scanHexInt:&rgbValue]) {
        return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0f green:((rgbValue & 0xFF00) >> 8)/255.0f blue:(rgbValue & 0xFF)/255.0f alpha:1.0f];
    } else {
        return nil;
    }
}

@end