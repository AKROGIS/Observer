//
//  AttributeViewController.h
//  Observer
//
//  Created by Regan Sarwas on 12/16/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>
#import "QuickDialogController.h"

@interface AttributeViewController : QuickDialogController

@property (nonatomic, strong) NSManagedObject *managedObject;
@property (nonatomic, strong) AGSGraphic *graphic;

@end
