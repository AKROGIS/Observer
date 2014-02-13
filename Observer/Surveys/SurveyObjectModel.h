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

+ (NSManagedObjectModel *) objectModelWithProtocol:(SProtocol *)protocol;

@end
