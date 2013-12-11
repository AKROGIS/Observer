//
//  SurveyObjectModel.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyObjectModel.h"

@implementation SurveyObjectModel

+ (NSManagedObjectModel *)objectModelWithProtocol:(SProtocol *)protocol
{
    NSAssert(protocol,@"protocol must be non-null");
    NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:nil];
    if (mom) {
        NSArray *features = protocol.features;
        for (NSDictionary *feature in features) {
            mom = [self mergeMom:mom entityName:feature[@"name"] attributes:feature[@"attributes"]];
        }
    }
    return mom;
}

+ (NSManagedObjectModel *) mergeMom:(NSManagedObjectModel *)mom entityName:(NSString *)name attributes:(NSArray *)attributes
{
    NSEntityDescription *entity;
    NSMutableArray *attributeProperties;
    if ([name isEqualToString:@"MissionProperty"] || [name isEqualToString:@"Observation"]) {
        entity = [[mom entitiesByName] valueForKey:name];
        attributeProperties = [NSMutableArray arrayWithArray:entity.properties];
    } else {
        NSEntityDescription *observation = [[mom entitiesByName] valueForKey:@"Observation"];
        entity = [[NSEntityDescription alloc] init];
        entity.name = name;
        observation.subentities = [[observation subentities] arrayByAddingObject:entity];
        mom.entities = [[mom entities] arrayByAddingObject:entity];
        attributeProperties = [NSMutableArray new];
    }
    for (id obj in attributes) {
        if ([obj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *attribute = (NSDictionary *)obj;
            NSAttributeDescription *attributeDescription = [[NSAttributeDescription alloc] init];
            [attributeProperties addObject:attributeDescription];
            //TODO: Check that unexpected values in an attribute dictionary does not cause a failure
            [attributeDescription setName:attribute[@"name"]];
            [attributeDescription setAttributeType:[attribute[@"type"] intValue]];
            [attributeDescription setOptional:[attribute[@"optional"] boolValue]];
            [attributeDescription setDefaultValue:attribute[@"default"]];
            NSArray *constraints = attribute[@"constraints"];
            if (constraints)
            {
                NSMutableArray *predicates = [[NSMutableArray alloc] init];
                NSMutableArray *warnings = [[NSMutableArray alloc] init];
                for (NSDictionary *constraint in constraints) {
                    [predicates addObject:[NSPredicate predicateWithFormat:constraint[@"predicate"]]];
                    [warnings addObject:constraint[@"warning"]];
                    [attributeDescription setValidationPredicates:predicates
                                           withValidationWarnings:warnings];
                }
            }
        }
    }
    [entity setProperties:attributeProperties];
    return mom;
}

@end
