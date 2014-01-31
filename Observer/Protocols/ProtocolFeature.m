//
//  ProtocolFeature.m
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolFeature.h"

@implementation ProtocolFeature

- (id)initWithJSON:(id)json
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
    id name = json[@"name"];
    if ([name isKindOfClass:[NSString class]]) {
        _name = (NSString *)name;
    }
    _allowedLocations = [[ProtocolFeatureAllowedLocations alloc] initWithLocationsJSON:json[@"locations"]];
    _symbology = [[ProtocolFeatureSymbology alloc] initWithSymbologyJSON:json[@"symbology"]];
    _attributes = [self buildAttributeArrayWithJSON:json[@"attributes"]];
    id dialog = json[@"dialog"];
    if ([dialog isKindOfClass:[NSDictionary class]]) {
        _dialogJSON = (NSDictionary *)dialog;
    }
}

// There are way to many ways to screw this up than I can test, for example:
// predicate ort warning may not be properly formated string
// name may be one of hundreds of illegal names
// type must be one of a limited number of non-sequential integers
// the default object must match the type.
// first priority is to use care when creating the protocol
// big problems will be discovered when the MOM is created (or rather not created)
// other problem need to be fereted out by testing.
- (NSArray *)buildAttributeArrayWithJSON:(id)json
{
    if ([json isKindOfClass:[NSArray class]]) {
        NSMutableArray *attributeProperties = [[NSMutableArray alloc] init];
        for (id item in json) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSAttributeDescription *attributeDescription = [[NSAttributeDescription alloc] init];
                [attributeProperties addObject:attributeDescription];
                id value = item[@"name"];
                if ([value isKindOfClass:[NSString class]]) {
                    //TODO: consider adding a generic 'obscuring' prefix to avoid reserved names
                    [attributeDescription setName:(NSString*)value];
                }
                value = item[@"type"];
                if ([value isKindOfClass:[NSNumber class]]) {
                    [attributeDescription setAttributeType:[(NSNumber*)value unsignedIntegerValue]];
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

@end
