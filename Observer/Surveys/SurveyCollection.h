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

//Does this collection manage the provided URL?
+ (BOOL) collectsURL:(NSURL *)url;

// builds the list, and current selection from the filesystem and user defaults
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

// returns the first survey that has the given (local) url
- (Survey *) surveyForURL:(NSURL *)url;

// Opens a survey file from the App delegate, and adds it to the begining of the list
- (BOOL)openURL:(NSURL *)url;

// Creates a new survey from the protocol and adds it to the list
// returns the index of the new survey (-1 if it could not be created)
- (NSInteger)newSurveyWithProtocol:(SProtocol *)protcol;

// UITableView DataSource Support
- (NSUInteger) numberOfSurveys;
- (Survey *) surveyAtIndex:(NSUInteger)index;
- (void) removeSurveyAtIndex:(NSUInteger)index;
- (void) moveSurveyAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void) setSelectedSurvey:(NSUInteger)index;
- (Survey *)selectedSurvey;

@end
