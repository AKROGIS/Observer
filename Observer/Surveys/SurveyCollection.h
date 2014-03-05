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


// There is only one list of surveys for the app.
// This list represents the singular collection of files on disk
+ (SurveyCollection *)sharedCollection;

+ (void)releaseSharedCollection;
//TODO: this is a memory optimization that needs to be validated and tested
//multiple instances will clash when saving state to the cache.
//However, I want to create and destroy the survey list with the view controller to
//avoid keeping the collection in memory if it isn't needed.  making a singleton object
//ensures that it is trapped in memory, unless I create a cleanup method that the VC calls
//when it disappears. - Not sure the best way to go here.

//Does this collection manage the provided URL?
+ (BOOL) collectsURL:(NSURL *)url;

// builds/verifies the list, and current selection from the filesystem and user defaults
// Warning this must be called from the main thread if it might be called multiple times
// assume completionHandler will be called on a background thread
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

// returns the first survey that has the given (local) url
- (Survey *) surveyForURL:(NSURL *)url;

// Opens a survey file from the App delegate, and adds it to the begining of the list
// TODO: check that it does similar checking like map/protocol
- (Survey *)openURL:(NSURL *)url;

// Creates a new survey from the protocol and adds it to the list
// returns the index of the new survey (NSNotFound if it could not be created)
- (NSUInteger)newSurveyWithProtocol:(SProtocol *)protcol;

// UITableView DataSource Support
- (NSUInteger) numberOfSurveys;
- (Survey *) surveyAtIndex:(NSUInteger)index;
- (void) insertSurvey:(Survey *)survey atIndex:(NSUInteger)index;
- (void) removeSurveyAtIndex:(NSUInteger)index;
- (void) moveSurveyAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void) setSelectedSurvey:(NSUInteger)index;
- (Survey *)selectedSurvey;

@end
