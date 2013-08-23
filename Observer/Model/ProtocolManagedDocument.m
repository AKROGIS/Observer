//
//  ProtocolManagedDocument.m
//  Observer
//
//  Created by Regan Sarwas on 8/22/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "ProtocolManagedDocument.h"

@interface ProtocolManagedDocument ()

//@property (nonatomic,retain) NSManagedObjectModel *myManagedObjectModel;

@end

NSManagedObjectModel *_myManagedObjectModel;

@implementation ProtocolManagedDocument

//-(NSManagedObjectModel*)myManagedObjectModel {}

//Override super's readonly property
-(NSManagedObjectModel*)managedObjectModel {
    if (!_myManagedObjectModel)
    {
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *modelPath = [bundle pathForResource:@"ObserverModel" ofType:@"momd"];
        _myManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:modelPath]];
    }
    return _myManagedObjectModel;
}
@end
