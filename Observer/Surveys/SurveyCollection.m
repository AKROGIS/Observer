//
//  SurveyCollection.m
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyCollection.h"
#import "NSArray+map.h"
#import "NSURL+unique.h"
#import "NSURL+isEqualToURL.h"
#import "Settings.h"
#import "AKRLog.h"

@interface SurveyCollection()
@property (nonatomic, strong) NSMutableArray *items;
@end

@implementation SurveyCollection

#pragma mark - singleton

static SurveyCollection *_sharedCollection = nil;
static BOOL _isLoaded = NO;

+ (SurveyCollection *) sharedCollection {
    @synchronized(self) {
        if (_sharedCollection == nil) {
            _sharedCollection = [[super allocWithZone:NULL] init];
        }
    }
    return _sharedCollection;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedCollection];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

+ (void)releaseSharedCollection {
    @synchronized(self) {
        _sharedCollection = nil;
        _isLoaded = NO;
    }
}




#pragma mark - Public methods

+ (BOOL)collectsURL:(NSURL *)url
{
    return [self isImportURL:url] || [self isPrivateURL:url];
}

+ (BOOL)isImportURL:(NSURL *)url
{
    return [url.pathExtension isEqualToString:SURVEY_EXT];
}

+ (BOOL)isPrivateURL:(NSURL *)url
{
    return [url.pathExtension isEqualToString:INTERNAL_SURVEY_EXT];
}

- (void)openWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    static BOOL isLoading = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        //Check and set self.isLoading on the main thread to guarantee there is no race condition.
        //_isLoaded guarantees that items is only set once (i.e. loadCache is only called once)
        if (_isLoaded) {
            if (completionHandler)
                completionHandler(self.items != nil);
        } else {
            if (isLoading) {
                //wait until loading is completed, then return;
                dispatch_async(dispatch_queue_create("gov.nps.akr.observer.surveycollection.open", DISPATCH_QUEUE_SERIAL), ^{
                    //This task is serial with the task that will clear isLoading, so it will not run until loading is done;
                    if (completionHandler) {
                        completionHandler(self.items != nil);
                    }
                });
            } else {
                isLoading = YES;
                dispatch_async(dispatch_queue_create("gov.nps.akr.observer.surveycollection.open", DISPATCH_QUEUE_SERIAL), ^{
                    [self loadCache];
                    [self refreshLocalSurveys];
                    _isLoaded = YES;
                    isLoading = NO;
                    if (completionHandler) {
                        completionHandler(self.items != nil);
                    }
                });
            }
        }
    });
}

- (Survey *)surveyWithURL:(NSURL *)url
{
    for (Survey *survey in self.items) {
        if ([survey.url isEqualToURL:url]) {
            return survey;
        }
    }
    return nil;
}

- (void)refreshWithCompletionHandler:(void (^)())completionHandler
{
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer", DISPATCH_QUEUE_CONCURRENT), ^{
        [self refreshLocalSurveys];
        if (completionHandler) {
            completionHandler();
        }
    });
}




#pragma mark - TableView Data Source Support

-(NSUInteger)numberOfSurveys
{
    return self.items.count;
}

- (Survey *)surveyAtIndex:(NSUInteger)index
{
    if (self.items.count <= index) {
        AKRLog(@"Array index out of bounds in [SurveyCollection survey:atIndex:%lu]; size = %lu",(unsigned long)index,(unsigned long)self.items.count);
        return nil;
    }
    return self.items[index];
}

- (void)insertSurvey:(Survey *)survey atIndex:(NSUInteger)index
{
    [self.items insertObject:survey atIndex:index];
    [self saveCache];
}

-(void)removeSurveyAtIndex:(NSUInteger)index
{
    if (self.items.count <= index) {
        AKRLog(@"Array index out of bounds in [SurveyCollection removeSurveyAtIndex:%lu] size = %lu",(unsigned long)index,(unsigned long)self.items.count);
        return;
    }
    Survey *item = [self surveyAtIndex:index];
    [item closeDocumentWithCompletionHandler:^(BOOL success){
        AKRLog(@"  Survey Document Closed; Success: %@", success ? @"YES" : @"NO");
        [[NSFileManager defaultManager] removeItemAtURL:item.url error:nil];
        AKRLog(@"  Survey Document Deleted");
    }];
    [self.items removeObjectAtIndex:index];
    [self saveCache];
}

-(void)moveSurveyAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex == toIndex)
        return;
    id temp = self.items[fromIndex];
    [self.items removeObjectAtIndex:fromIndex];
    [self.items insertObject:temp atIndex:toIndex];
    [self saveCache];
}




#pragma mark - private methods

#pragma mark - private properties

- (NSMutableArray *)items
{
    if (!_items) {
        _items = [NSMutableArray new];
    }
    return _items;
}




#pragma mark - Cache operations

- (void)loadCache
{
    NSArray *surveyNames = [Settings manager].surveys;
    self.items = [surveyNames mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        NSString *name = (NSString *)obj;
        return [[Survey alloc] initWithURL:[Survey urlFromCachedName:name]];
    }];
}

- (void)saveCache
{
    [Settings manager].surveys = [self.items mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        Survey *survey = (Survey *)obj;
        return survey.lastPathComponent;
    }];
}




#pragma mark - Local Surveys

- (void) refreshLocalSurveys
{
    BOOL modelChanged = NO;

    // Get a list of the Filenames (url.lastpathcomponent) of the surveys in the private survey folder
    NSSet *privateSurveyFilenames = [SurveyCollection existingPrivateSurveyNames];

    //Assume that all the survey files are new; we will remove them from the set if we have a survey for the filename
    NSMutableSet *newFilenames = [[NSMutableSet alloc] initWithSet:privateSurveyFilenames];

    // Assume we do not have any extra (unfound surveys)
    NSMutableArray *surveysToRemove = [NSMutableArray new];

    // Find any surveys not in the private survey folder
    // And any paths in the private survey folder not in the surveys
    for (Survey *survey in self.items) {
        NSString *surveyFilename = survey.url.lastPathComponent;
        if ([newFilenames containsObject:surveyFilename]) {
            [newFilenames removeObject:surveyFilename];
        } else {
            [surveysToRemove addObject:survey];
        }
    }

    // Remove unfound surveys;
    // This should never happen, since a survey should only have a URL in the private survey folder,
    // We do not need to worry about closing the survey, since it's URL is bad, it can't have an open document
    for (Survey *survey in surveysToRemove) {
        AKRLog(@"WARNING: You have a survey %@ at %@ not in the private folder; Removing", survey.title, survey.url);
        //[survey delete];
        [self.items removeObject:survey];
        modelChanged = YES;
    }

    // Add new survey to items for new Filenames
    // This will happen when a user opens a *.poz file from email or safari.
    for (NSString *name in newFilenames) {
        AKRLog(@"SURPRISE: You have a survey folder %@ not in your cache; Creating", name);
        NSURL *surveyUrl = [[Survey privateDocumentsDirectory] URLByAppendingPathComponent:name];
        Survey *newSurvey = [[Survey alloc] initWithURL:surveyUrl];
        [self.items addObject:newSurvey];
        modelChanged = YES;
    }

    //Add surveys that were added to the public (iTunes) folder;

    //First check for raw (private extensions) surveys.  This will probably only be done by developers.
    //The survey init method will move the survey from the public iTunes folder to the private folder.
    for (NSString *publicSurveyFileName in [SurveyCollection existingPublicSurveyNames]) {
        NSURL *surveyUrl = [[SurveyCollection documentsDirectory] URLByAppendingPathComponent:publicSurveyFileName];
        // Trying to create a survey outside the private folder will move they survey and change the url property
        [self.items addObject:[[Survey alloc] initWithURL:surveyUrl]];
        modelChanged = YES;
    }

    // Second, check for archived (*.poz) surveys
    // I cannot add importable (*.poz) surveys in the public (iTunes) folder because they may be exports of surveys I'm already managing.
    // See Issue #90 (https://github.com/regan-sarwas/Observer/issues/90) for a discussion of options.

    if (modelChanged) {
        [self saveCache];
    }
}

+ (NSSet *) /* of NSString */ existingPrivateSurveyNames
{
    NSError *error = nil;
    NSArray *documents = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtURL:[Survey privateDocumentsDirectory]
                          includingPropertiesForKeys:nil
                          options:NSDirectoryEnumerationSkipsHiddenFiles
                          error:&error];
    if (documents) {
        NSMutableArray *localFileNames = [NSMutableArray new];
        for (NSURL *url in documents) {
            NSString *name = url.lastPathComponent;
            if (name != nil && [SurveyCollection isPrivateURL:url]) {
                [localFileNames addObject:name];
            }
        }
        return [NSSet setWithArray:localFileNames];
    }
    AKRLog(@"Unable to enumerate %@: %@",[[Survey privateDocumentsDirectory] lastPathComponent], error.localizedDescription);
    return nil;
}

+ (NSMutableSet *) /* of NSString */ existingPublicSurveyNames
{
    NSError *error = nil;
    NSArray *documents = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtURL:self.documentsDirectory
                          includingPropertiesForKeys:nil
                          options:NSDirectoryEnumerationSkipsHiddenFiles
                          error:&error];
    if (documents) {
        NSMutableArray *localFileNames = [NSMutableArray new];
        for (NSURL *url in documents) {
            NSString *name = url.lastPathComponent;
            if (name != nil && [SurveyCollection isPrivateURL:url]) {
                [localFileNames addObject:name];
            }
        }
        return [NSMutableSet setWithArray:localFileNames];
    }
    AKRLog(@"Unable to enumerate %@: %@",[self.documentsDirectory lastPathComponent], error.localizedDescription);
    return nil;
}

// Currently not used.  Save for Issue #90 (https://github.com/regan-sarwas/Observer/issues/90)
+ (NSMutableSet *) /* of NSString */ importableSurveyNames
{
    NSError *error = nil;
    NSArray *documents = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtURL:self.documentsDirectory
                          includingPropertiesForKeys:nil
                          options:NSDirectoryEnumerationSkipsHiddenFiles
                          error:&error];
    if (documents) {
        NSMutableArray *localFileNames = [NSMutableArray new];
        for (NSURL *url in documents) {
            NSString *name = url.lastPathComponent;
            if (name != nil && [SurveyCollection isImportURL:url]) {
                [localFileNames addObject:name];
            }
        }
        return [NSMutableSet setWithArray:localFileNames];
    }
    AKRLog(@"Unable to enumerate %@: %@",[self.documentsDirectory lastPathComponent], error.localizedDescription);
    return nil;
}

+ (NSURL *)documentsDirectory
{
    static NSURL *_documentsDirectory = nil;
    if (!_documentsDirectory) {
        _documentsDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    }
    return _documentsDirectory;
}

@end
