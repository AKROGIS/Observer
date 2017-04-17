//
//  ProtocolMissionFeature.m
//  Observer
//
//  Created by Regan Sarwas on 2/4/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolMissionFeature.h"

@implementation ProtocolMissionFeature

- (id)initWithJSON:(id)json version:(NSInteger) version
{
    self = [super initWithJSON:json version:version];
    if (self) {
        if ([json isKindOfClass:[NSDictionary class]]) {
            switch (version) {
                case 1:
                    [self defineMissionReadonlyProperties:json version:version];
                    break;
                case 2:
                    [self defineV2Renderers:json];
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
- (void)defineMissionReadonlyProperties:(NSDictionary *)json version:(NSInteger)version
{

    AGSMarkerSymbol *symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[UIColor blueColor]];
    [symbol setSize:CGSizeMake(6,6)];
    ProtocolFeatureSymbology *observingSymbology = [[ProtocolFeatureSymbology alloc] initWithSymbologyJSON:json[@"on-symbology"] version:version];
    ProtocolFeatureSymbology *notObservingSymbology = [[ProtocolFeatureSymbology alloc] initWithSymbologyJSON:json[@"off-symbology"] version:version];
    _lineRendererObserving = [AGSSimpleRenderer simpleRendererWithSymbol:observingSymbology.agsLineSymbol];
    _lineRendererNotObserving = [AGSSimpleRenderer simpleRendererWithSymbol:notObservingSymbology.agsLineSymbol];
    _pointRendererGps = [AGSSimpleRenderer simpleRendererWithSymbol:symbol];
}

- (void)defineV2Renderers:(NSDictionary *)json
{
    @try {
        //protect against malformed symbology definition in the protocol (JSON) file
        _lineRendererObserving = [self AGSRendererFromJSON:json[@"on-symbology"]];
        _lineRendererNotObserving = [self AGSRendererFromJSON:json[@"off-symbology"]];
        _pointRendererGps = [self AGSRendererFromJSON:json[@"gps-symbology"]];
    } @catch (NSException *exception) {
        AKRLog(@"Failed to create renderers (bad protocol): %@", exception);
        //Create a simple default
        AGSSimpleLineSymbol *symbol = [AGSSimpleLineSymbol simpleLineSymbol];
        symbol.color =  [UIColor redColor];
        symbol.width = 3;
        _lineRendererObserving = [AGSSimpleRenderer simpleRendererWithSymbol:symbol];
        symbol = [AGSSimpleLineSymbol simpleLineSymbol];
        symbol.color =  [UIColor grayColor];
        symbol.width = 1.5;
        _lineRendererNotObserving = [AGSSimpleRenderer simpleRendererWithSymbol:symbol];
        AGSMarkerSymbol *msymbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[UIColor blueColor]];
        [msymbol setSize:CGSizeMake(6,6)];
        _pointRendererGps = [AGSSimpleRenderer simpleRendererWithSymbol:msymbol];
    }
}

@end
