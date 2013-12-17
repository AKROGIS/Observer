//
//  Survey.h
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AKRTableViewItemCollection.h"
#import "SProtocol.h"
#import "SurveyCoreDataDocument.h"

#define SURVEY_EXT @"obssurv"

typedef NS_ENUM(NSUInteger, SurveyState) {
    kUnborn   = 0,
    kCorrupt  = 1,
    kCreated  = 2,
    kModified = 3,
    kSaved    = 4
};

@interface Survey : NSObject <AKRTableViewItem>

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, readonly) SurveyState state;
@property (nonatomic, strong, readonly) NSString *subtitle;

//title and date will block (reading values from the filessytem) if the state is unborn.
//To avoid the potential delay, call readPropertiesWithCompletionHandler first
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong, readonly) NSDate *date;

//The following methods will block (reading data from the filessytem)
//To avoid the potential delay, call openPropertiesWithCompletionHandler first
@property (nonatomic, strong, readonly) UIImage *thumbnail;
@property (nonatomic, strong, readonly) SProtocol *protocol;

//document will return nil until openDocumentWithCompletionHandler is called with success
@property (nonatomic, strong, readonly) UIManagedDocument *document;

//Initializers
// init will always return nil
//- (id)init //overridden to always return nil, use the designated initializer
// Designated Initializer  (typically not called directly
- (id)initWithURL:(NSURL *)url;
//This involve doing IO (to find and create the unused url), it should be called on a background thread
- (id)initWithProtocol:(SProtocol *)protocol;

//other actions
//load all properties
- (void)readPropertiesWithCompletionHandler:(void (^)(NSError*))handler;
- (void)openDocumentWithCompletionHandler:(void (^)(BOOL success))handler;
//- (void)closeWithCompletionHandler:(void (^)(NSError*))handler;
- (void)syncWithCompletionHandler:(void (^)(NSError*))handler;

//TODO: memory releaser (unload properties), reset object to unborn
//
- (void)saveWithCompletionHandler:(void (^)(BOOL success))completionHandler;
- (void)closeWithCompletionHandler:(void (^)(BOOL success))completionHandler;

@end
