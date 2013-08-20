//
//  AttributeSet.h
//  Observer
//
//  Created by Regan Sarwas on 8/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MissionProperty, Observation;

@interface AttributeSet : NSManagedObject

@property (nonatomic, retain) MissionProperty *missionProperty;
@property (nonatomic, retain) Observation *observation;

@end
