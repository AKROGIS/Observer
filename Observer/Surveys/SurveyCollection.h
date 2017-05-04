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

//Return the optional survey if there is one in the collection with this URL
- (Survey *)surveyWithURL:(NSURL *)url;

// Builds the ordered lists of remote and local protocols from a saved cache.
// Cache is corrected for changes in the local files system.
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

// Refresh the list of surveys
// Will NOT send message to a delegate or post notifications.
// Use the completion handler to reload the UITableView
- (void)refreshWithCompletionHandler:(void (^)())completionHandler;

// UITableView DataSource Support
@property (nonatomic, readonly) NSUInteger numberOfSurveys;
// Returns nil if index out of bounds (semantics - there is no survey at the index)
- (Survey *)surveyAtIndex:(NSUInteger)index;
// Throws an exception if index is greater than the number of local maps
- (void)insertSurvey:(Survey *)survey atIndex:(NSUInteger)index;
// No-op if index out of bounds (semantics - the survey at the index is already gone)
// Caller is responsible for closing survey before deleting.
- (void)removeSurveyAtIndex:(NSUInteger)index;
// Throws an exception if either index is out of bounds
- (void)moveSurveyAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

@end
