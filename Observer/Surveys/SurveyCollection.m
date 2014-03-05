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
#import "Settings.h"

@interface SurveyCollection()
@property (nonatomic, strong) NSMutableArray *items;
@end

@implementation SurveyCollection

#pragma mark - singleton

+ (SurveyCollection *) sharedCollection {
    static SurveyCollection *_sharedCollection = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (_sharedCollection == nil) {
            _sharedCollection = [[super allocWithZone:NULL] init];
        }
    });
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
    //TODO: I can't release the shared collection with this type of singleton.
    //This optimization may not be necessary
    //_sharedCollection = nil;
}

#pragma mark - private properties

- (NSMutableArray *)items
{
    if (!_items) {
        _items = [NSMutableArray new];
    }
    return _items;
}

+ (NSURL *)documentsDirectory
{
    static NSURL *_documentsDirectory = nil;
    if (!_documentsDirectory) {
        _documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    }
    return _documentsDirectory;
}



#pragma mark - Public methods

+ (BOOL) collectsURL:(NSURL *)url
{
    return [[url pathExtension] isEqualToString:SURVEY_EXT];
}


- (void)openWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    static BOOL isLoaded = NO;
    static BOOL isLoading = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        //Check and set self.isLoading on the main thread to guarantee there is no race condition.
        if (isLoaded) {
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
                    [self loadAndCorrectListOfSurveys];
                    isLoaded = YES;
                    isLoading = NO;
                    if (completionHandler) {
                        completionHandler(self.items != nil);
                    }
                });
            }
        }
    });
}

- (Survey *)surveyForURL:(NSURL *)url
{
    NSUInteger index = [self.items indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [url isEqual:[obj url]];
    }];
    return (index == NSNotFound) ? nil : [self.items objectAtIndex:index];
}

//TODO: test opening a Survey document
- (Survey *)openURL:(NSURL *)url
{
    //The only known use of this is by the app delegate to give us a file in the inbox
    //however, I will make it as generic as possible
    
    //If we already have a survey at that url, then do nothing.
    Survey *newSurvey = [self surveyForURL:url];

    if (newSurvey) {
        return newSurvey;
    }
    NSURL *newUrl = [[SurveyCollection documentsDirectory] URLByAppendingPathComponent:[url lastPathComponent]];
    //If the url is already in the documents directory then do not move it
    if (![newUrl isEqual:url]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[newUrl path]]) {
            newUrl = [newUrl URLByUniquingPath];
        }
        if (![[NSFileManager defaultManager] moveItemAtURL:url toURL:newUrl error:nil]) {
            return nil;
        }
    }
    newSurvey = [[Survey alloc] initWithURL:newUrl];
    if ([newSurvey isValid]) {
        NSUInteger index = 0;     //insert at top of list
        [self.items insertObject:newSurvey atIndex:index];
        [self saveCache];
        return newSurvey;
    } else {
        [[NSFileManager defaultManager] removeItemAtURL:newUrl error:nil];
        return nil;
    }
}

- (NSUInteger)newSurveyWithProtocol:(SProtocol *)protocol {
    Survey *newSurvey = [[Survey alloc] initWithProtocol:protocol];
    if (newSurvey) {
        NSUInteger index = 0;     //insert at top of list
        [self.items insertObject:newSurvey atIndex:index];
        [self saveCache];
        return index;
    } else {
        return NSNotFound;
    }
}



#pragma mark - TableView Data Source Support

-(NSUInteger)numberOfSurveys
{
    return self.items.count;
}

- (Survey *)surveyAtIndex:(NSUInteger)index
{
    if (self.items.count <= index) return nil; //safety check
    return self.items[index];
}

- (void)insertSurvey:(Survey *)survey atIndex:(NSUInteger)index
{
    //if (self.items.count < index) return; //safety check
    [self.items insertObject:survey atIndex:index];
    [self saveCache];
}

-(void)removeSurveyAtIndex:(NSUInteger)index
{
    if (self.items.count <= index) return; //safety check
    Survey *item = [self surveyAtIndex:index];
    //TODO: if the document is open, close it first, or set it to nil, so subsequent attempts to close it do not generate errors.
    [[NSFileManager defaultManager] removeItemAtURL:item.url error:nil];
    [self.items removeObjectAtIndex:index];
    [self saveCache];
}

-(void)moveSurveyAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (self.items.count <= fromIndex || self.items.count <= toIndex) return;  //safety check
    if (fromIndex == toIndex)
        return;

    //move the item
    id temp = self.items[fromIndex];
    [self.items removeObjectAtIndex:fromIndex];
    [self.items insertObject:temp atIndex:toIndex];
    [self saveCache];
}



#pragma mark - private methods

- (void) loadAndCorrectListOfSurveys
{
    //NOTE: compare file name (without path), because iOS is inconsistent about symbolic links at root of documents path
    BOOL cacheWasOutdated = NO;
    NSArray *cachedSurveyUrls = [Settings manager].surveys;
    
    // create (in order) surveys from cached urls IFF they are found in the Documents Folder
    NSMutableSet *localSurveyFileNames = [SurveyCollection surveyFileNamesInDocumentsFolder];
    for (NSURL *cachedSurveyUrl in cachedSurveyUrls) {
        NSString *cachedSurveyFileName = [cachedSurveyUrl lastPathComponent];
        if ([localSurveyFileNames containsObject:cachedSurveyFileName]) {
            [self.items addObject:[[Survey alloc] initWithURL:cachedSurveyUrl]];
            [localSurveyFileNames removeObject:cachedSurveyFileName];
        }
    }
    if (self.items.count < cachedSurveyUrls.count) {
        cacheWasOutdated = YES;
    }

    //Add any other Surveys in filesystem (maybe added via iTunes) to end of list from cached list
    for (NSString *localSurveyFileName in localSurveyFileNames) {
        NSURL *surveyUrl = [[SurveyCollection documentsDirectory] URLByAppendingPathComponent:localSurveyFileName];
        [self.items addObject:[[Survey alloc] initWithURL:surveyUrl]];
        cacheWasOutdated = YES;
    }

    if (cacheWasOutdated) {
        [self saveCache];
    }
}

+ (NSMutableSet *) /* of NSString */ surveyFileNamesInDocumentsFolder
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
            if ([SurveyCollection collectsURL:url]) {
                [localFileNames addObject:[url lastPathComponent]];
            }
        }
        return [NSMutableSet setWithArray:localFileNames];;
    }
    AKRLog(@"Unable to enumerate %@: %@",[self.documentsDirectory lastPathComponent], error.localizedDescription);
    return nil;
}


- (void)saveCache
{
    [Settings manager].surveys = [self.items mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        return [obj url];
    }];
}

@end
