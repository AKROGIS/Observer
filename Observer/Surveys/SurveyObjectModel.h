//
//  SurveyObjectModel.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "SProtocol.h"

@interface SurveyObjectModel : NSObject


// FIXME: implement contract described below
// Each feature in the protocol is a new entity in the MOM as a subclass of the 'kObservationEntityName' entity
// The attributes of the mission in the protocol add attributes to the 'kMissionPropertyEntityName' entity

+ (NSManagedObjectModel *) objectModelWithProtocol:(SProtocol *)protocol;

@end
