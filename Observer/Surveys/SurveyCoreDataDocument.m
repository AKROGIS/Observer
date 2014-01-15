//
//  SurveyCoreDataDocument.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyCoreDataDocument.h"
#import "SurveyObjectModel.h"
#import "SurveyCollection.h"

@implementation SurveyCoreDataDocument

- (NSManagedObjectModel *)managedObjectModel
{
    //assumes that the survey collecion is loaded. must be true to create/open a survey document
    Survey *survey = [[SurveyCollection sharedCollection] surveyForURL:[self.fileURL URLByDeletingLastPathComponent]];
    return [SurveyObjectModel objectModelWithProtocol:survey.protocol];
}

#ifdef DEBUG
- (id)contentsForType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
    NSLog(@"Auto-Saving SurveyCoreDataDocument");
    return [super contentsForType:typeName error:outError];
}

- (void)handleError:(NSError *)error userInteractionPermitted:(BOOL)userInteractionPermitted {
    NSLog(@"SurveyCoreDataDocument %@ has error.", self.fileURL);
    NSLog(@"    State: %d", self.documentState);
    NSLog(@"    Error: %@", error);
    [super handleError:error userInteractionPermitted:userInteractionPermitted];
}
#endif

@end
