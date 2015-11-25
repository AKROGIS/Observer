//
//  SurveyCoreDataDocument.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyCoreDataDocument.h"
#import "SurveyObjectModel.h"
#import "Survey.h"

@implementation SurveyCoreDataDocument

- (NSManagedObjectModel *)managedObjectModel
{
    Survey *survey = [[Survey alloc] initWithURL:[self.fileURL URLByDeletingLastPathComponent]];
    return [SurveyObjectModel objectModelWithProtocol:survey.protocol];
}

#ifdef DEBUG
- (id)contentsForType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
    AKRLog(@"Auto-Saving SurveyCoreDataDocument");
    return [super contentsForType:typeName error:outError];
}

- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted {
    AKRLog(@"SurveyCoreDataDocument %@ has error.", self.fileURL);
    AKRLog(@"    State: %lu", (unsigned long)self.documentState);
    AKRLog(@"    Error: %@", error);
    [super handleError:error userInteractionPermitted:userInteractionPermitted];
}
#endif

@end
