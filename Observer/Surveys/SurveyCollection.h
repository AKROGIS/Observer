//
//  SurveyCollection.h
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SProtocol.h"
#import "Survey.h"

@interface SurveyCollection : NSObject


// This list represents the ordered collection of survey files in the filesystem
// It is a singleton, to avoid synchronization issues between multiple instances
+ (SurveyCollection *)sharedCollection;

// This will release the memory used by the collection
+ (void)releaseSharedCollection;

//Does this collection manage the provided URL?
+ (BOOL)collectsURL:(NSURL *)url;

// builds/verifies the list, and current selection from the filesystem and user defaults
// Warning this must be called from the main thread if it might be called multiple times
// assume completionHandler will be called on a background thread
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

// returns the first survey that has the given (local) url
- (Survey *)surveyForURL:(NSURL *)url;

// Creates a new survey from the protocol and adds it to the list
// returns the index of the new survey (NSNotFound if it could not be created)
- (NSUInteger)newSurveyWithProtocol:(SProtocol *)protcol;

// UITableView DataSource Support
- (NSUInteger) numberOfSurveys;
- (Survey *) surveyAtIndex:(NSUInteger)index;
- (void) insertSurvey:(Survey *)survey atIndex:(NSUInteger)index;
- (void) removeSurveyAtIndex:(NSUInteger)index;
- (void) moveSurveyAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

@end
