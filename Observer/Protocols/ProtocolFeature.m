//
//  ProtocolFeature.m
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolFeature.h"
#import "ObserverModel.h"

@implementation ProtocolFeature

static NSUInteger currentUniqueId = 0;

- (id)initWithJSON:(id)json version:(NSInteger) version
{
    if (self = [super init]) {
        if ([json isKindOfClass:[NSDictionary class]]) {
            switch (version) {
                case 1:
                case 2:
                    [self defineReadonlyProperties:json version:version];
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
- (void)defineReadonlyProperties:(NSDictionary *)json version:(NSInteger) version
{
    id name = json[@"name"];
    if ([name isKindOfClass:[NSString class]]) {
        _name = (NSString *)name;
    }
    _allowedLocations = [[ProtocolFeatureAllowedLocations alloc] initWithLocationsJSON:json[@"locations"]version:version];
    [self defineReadonlySymbology:json[@"symbology"] version:version];
    _labelSpec = [[ProtocolFeatureLabel alloc] initWithLabelJSON:json[@"label"] version:version];
    _attributes = [self buildAttributeArrayWithJSON:json[@"attributes"] version:version];
    id dialog = json[@"dialog"];
    if ([dialog isKindOfClass:[NSDictionary class]]) {
        _dialogJSON = (NSDictionary *)dialog;
    }
}

// There are way to many ways to screw this up than I can test, for example:
// predicate or warning may not be properly formated strings
// name may be one of hundreds of illegal names
// type must be one of a limited number of non-sequential integers
// a default object (if provided) must match the type.
// first priority is to use care when creating the protocol
// big problems will be discovered when the MOM is created (or rather not created)
// other problem need to be fereted out by testing protocol before field work.
- (NSArray *)buildAttributeArrayWithJSON:(id)json  version:(NSInteger) version
{
    if ([json isKindOfClass:[NSArray class]]) {
        NSMutableArray *attributeProperties = [[NSMutableArray alloc] init];
        for (id item in json) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSAttributeDescription *attributeDescription = [[NSAttributeDescription alloc] init];
                [attributeProperties addObject:attributeDescription];
                id value = item[@"name"];
                NSString *obscuredName;
                if ([value isKindOfClass:[NSString class]]) {
                    obscuredName = [NSString stringWithFormat:@"%@%@",kAttributePrefix,value];
                    [attributeDescription setName:obscuredName];
                }
                value = item[@"type"];
                if ([value isKindOfClass:[NSNumber class]]) {
                    NSUInteger type = [(NSNumber*)value unsignedIntegerValue];
                    if (type == 0) {
                        type = 200;
                        _hasUniqueId = YES;
                        _uniqueIdName = obscuredName;
                    }
                    [attributeDescription setAttributeType:type];
                }
                value = item[@"required"];
                if ([value isKindOfClass:[NSNumber class]]) {
                    [attributeDescription setOptional:[(NSNumber*)value boolValue]];
                }
                [attributeDescription setDefaultValue:item[@"default"]];
                value = item[@"constraints"];
                if ([value isKindOfClass:[NSArray class]]) {
                    NSMutableArray *predicates = [[NSMutableArray alloc] init];
                    NSMutableArray *warnings = [[NSMutableArray alloc] init];
                    for (id constraintItem in (NSArray *)value) {
                        if ([constraintItem isKindOfClass:[NSDictionary class]]) {
                            NSDictionary *constraint = (NSDictionary *)constraintItem;
                            NSString *predicate = nil;
                            NSString *warning = nil;
                            id value1 = constraint[@"predicate"];
                            if ([value1 isKindOfClass:[NSString class]]) {
                                predicate = (NSString*)value1;
                            }
                            value1 = constraint[@"warning"];
                            if ([value1 isKindOfClass:[NSString class]]) {
                                warning = (NSString*)value1;
                            }
                            if (predicate && warning) {
                                [predicates addObject:[NSPredicate predicateWithFormat:predicate]];
                                [warnings addObject:warning];
                            }
                        }
                    }
                    [attributeDescription setValidationPredicates:predicates
                                           withValidationWarnings:warnings];
                }
            }
        }
        return attributeProperties;
    }
    return nil;
}

- (NSNumber *)nextUniqueId
{
    return [NSNumber numberWithUnsignedInteger:++currentUniqueId];
}

- (void)initUniqueId:(NSNumber *)id
{
    currentUniqueId = [id unsignedIntegerValue];
}

- (WaysToLocateFeature) locationMethod
{
    WaysToLocateFeature locationMethod = self.allowedLocations.defaultNonTouchChoice;
    if (!locationMethod) {
        if (!self.preferredLocationMethod) {
            self.preferredLocationMethod = self.allowedLocations.initialNonTouchChoice;
        }
        locationMethod = self.preferredLocationMethod;
    }
    return locationMethod;
}

- (void)defineReadonlySymbology:(NSDictionary *)json version:(NSInteger) version
{
    switch (version) {
        case 1:
        {
             ProtocolFeatureSymbology *symbology = [[ProtocolFeatureSymbology alloc] initWithSymbologyJSON:json version:version];
            _pointRenderer = [AGSSimpleRenderer simpleRendererWithSymbol:symbology.agsMarkerSymbol];
            break;
        }
        case 2:
            @try {
                //protect against malformed symbology definition in the protocol (JSON) file
                _pointRenderer = [self AGSRendererFromJSON:json];
            } @catch (NSException *exception) {
                AKRLog(@"Failed to create feature renderer (bad protocol): %@", exception);
                //Create a simple default
                AGSMarkerSymbol *symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[UIColor greenColor]];
                [symbol setSize:CGSizeMake(12,12)];
                _pointRenderer = [AGSSimpleRenderer simpleRendererWithSymbol:symbol];
            }
            break;
        default:
            AKRLog(@"Unsupported version (%ld) of the NPS-Protocol-Specification", (long)version);
            break;
    }
}

- (void)defineReadonlyLabel:(NSDictionary *)json version:(NSInteger) version
{
    switch (version) {
        case 1:
        {
            _labelSpec = nil;
            break;
        }
        case 2:
        @try {
            //protect against malformed symbology definition in the protocol (JSON) file
            _pointRenderer = [self AGSRendererFromJSON:json];
        } @catch (NSException *exception) {
            AKRLog(@"Failed to create feature renderer (bad protocol): %@", exception);
            //Create a simple default
            AGSMarkerSymbol *symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[UIColor greenColor]];
            [symbol setSize:CGSizeMake(12,12)];
            _pointRenderer = [AGSSimpleRenderer simpleRendererWithSymbol:symbol];
        }
        break;
        default:
        AKRLog(@"Unsupported version (%ld) of the NPS-Protocol-Specification", (long)version);
        break;
    }
}



- (AGSRenderer *)AGSRendererFromJSON:(NSDictionary *)json
{
    NSString *rendererType = json[@"type"];
    if ([rendererType isEqualToString:@"simple"]) {
        return [[AGSSimpleRenderer alloc] initWithJSON:json];
    }
    if ([rendererType isEqualToString:@"classBreaks"]) {
        return [[AGSClassBreaksRenderer alloc] initWithJSON:json];
    }
    if ([rendererType isEqualToString:@"uniqueValue"]) {
        return [[AGSUniqueValueRenderer alloc] initWithJSON:json];
    }
    return [[AGSRenderer alloc] initWithJSON:json];
    //TODO: starting in version 100 (quartz) replace this method with
    //return [AGSRenderer fromJSON:json]
}

@end
