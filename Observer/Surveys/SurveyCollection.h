//
//  SurveyCollection.h
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AKRTableViewItemCollection.h"
#import "SProtocol.h"
#import "Survey.h"

@interface SurveyCollection : NSObject

//<AKRTableViewItemCollection>
//@property (nonatomic, strong) NSIndexPath * selectedIndex;
//@property (nonatomic, strong, readonly) Survey *selectedSurvey;

// There is only one list of surveys for the app.
// This list represents the singular collection of files on disk
+ (SurveyCollection *)sharedCollection;

- (Survey *) surveyForURL:(NSURL *)url;

//Does this collection manage the provided URL?
+ (BOOL) collectsURL:(NSURL *)url;

// builds the list, and current selection from the filesystem and user defaults
- (void)openWithCompletionHandler:(void (^)(BOOL success))completionHandler;

// opens a file from the App delegate
- (BOOL)openURL:(NSURL *)url;

- (NSInteger)newSurveyWithProtocol:(SProtocol *)protcol;


// UITableView DataSource Support
- (NSUInteger) numberOfSurveys;
- (Survey *) surveyAtIndex:(NSUInteger)index;
- (void) removeSurveyAtIndex:(NSUInteger)index;
- (void) moveSurveyAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void) setSelectedSurvey:(NSUInteger)index;
- (Survey *)selectedSurvey;

@end
