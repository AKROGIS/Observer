//
//  SurveyObjectModel.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "CommonDefines.h"
#import "SurveyObjectModel.h"

@implementation SurveyObjectModel

+ (NSManagedObjectModel *)objectModelWithProtocol:(SProtocol *)protocol
{
    NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:nil];
    if (mom) {
        //AKRLog(@"Merging MOM, starting with %@",mom);
        mom = [self mergeMom:mom missionAttributes:protocol.missionFeature.attributes];
        for (ProtocolFeature *feature in protocol.features) {
            mom = [self mergeMom:mom featureName:feature.name attributes:feature.attributes];
        }
    }
    return mom;
}

+ (NSManagedObjectModel *) mergeMom:(NSManagedObjectModel *)mom missionAttributes:(NSArray *)attributes
{
    NSEntityDescription *entity = [mom.entitiesByName valueForKey:kMissionPropertyEntityName];
    NSMutableArray *attributeProperties = [NSMutableArray arrayWithArray:entity.properties];
    [attributeProperties addObjectsFromArray:attributes];
    entity.properties = attributeProperties;
    return mom;
}

+ (NSManagedObjectModel *) mergeMom:(NSManagedObjectModel *)mom featureName:(NSString *)name attributes:(NSArray *)attributes
{
    NSString *entityName = [NSString stringWithFormat:@"%@%@",kObservationPrefix,name];
    NSEntityDescription *testEntity = [mom.entitiesByName valueForKey:entityName];
    if (testEntity) {
        return mom;
    }
    NSEntityDescription *observation = [mom.entitiesByName valueForKey:kObservationEntityName];
    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    entity.name = entityName;
    entity.managedObjectClassName = @"Observation";
    observation.subentities = [observation.subentities arrayByAddingObject:entity];
    mom.entities = [mom.entities arrayByAddingObject:entity];
    entity.properties = attributes;
    return mom;
}

@end
