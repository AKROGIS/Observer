//
//  SurveyObjectModel.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyObjectModel.h"
#import "ObserverModel.h"

@implementation SurveyObjectModel

+ (NSManagedObjectModel *)objectModelWithProtocol:(SProtocol *)protocol
{
    NSAssert(protocol,@"protocol must be non-null");
    NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:nil];
    if (mom) {
        mom = [self mergeMom:mom missionAttributes:protocol.missionFeature.attributes];
        for (ProtocolFeature *feature in protocol.features) {
            mom = [self mergeMom:mom featureName:feature.name attributes:feature.attributes];
        }
    }
    return mom;
}

+ (NSManagedObjectModel *) mergeMom:(NSManagedObjectModel *)mom missionAttributes:(NSArray *)attributes
{
    NSEntityDescription *entity = [[mom entitiesByName] valueForKey:kMissionPropertyEntityName];
    NSMutableArray *attributeProperties = [NSMutableArray arrayWithArray:entity.properties];
    [attributeProperties addObjectsFromArray:attributes];
    [entity setProperties:attributeProperties];
    return mom;
}

+ (NSManagedObjectModel *) mergeMom:(NSManagedObjectModel *)mom featureName:(NSString *)name attributes:(NSArray *)attributes
{
    //TODO: test proper behavior when name exists
    //bail if the name is taken
    NSEntityDescription *testEntity = [[mom entitiesByName] valueForKey:name];
    if (testEntity) {
        return mom;
    }
    //TODO: consider adding a generic 'obscuring' prefix to avoid reserved names
    NSEntityDescription *observation = [[mom entitiesByName] valueForKey:kObservationEntityName];
    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    entity.name = name;
    observation.subentities = [[observation subentities] arrayByAddingObject:entity];
    mom.entities = [[mom entities] arrayByAddingObject:entity];
//    // Do I need to copy the parent attributes when it is a sub entitity?  I don't think so
//    NSMutableArray *attributeProperties = [NSMutableArray arrayWithArray:entity.properties];
//    [attributeProperties addObjectsFromArray:attributes];
//    [attributeProperties addObjectsFromArray:attributes];
    [entity setProperties:attributes];
    return mom;
}

@end
