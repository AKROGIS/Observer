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
    return [[url pathExtension] isEqualToString:SURVEY_EXT];
}

+ (BOOL)isPrivateURL:(NSURL *)url
{
    return [[url pathExtension] isEqualToString:INTERNAL_SURVEY_EXT];
}

- (void)openWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    static BOOL isLoading = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        //Check and set self.isLoading on the main thread to guarantee there is no race condition.
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
    NSArray *surveyUrls = [Settings manager].surveys;
    self.items = [surveyUrls mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        return [[Survey alloc] initWithURL:obj];
    }];
}

- (void)saveCache
{
    [Settings manager].surveys = [self.items mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        return [obj url];
    }];
}




#pragma mark - Local Surveys

- (void) refreshLocalSurveys
{
    //NOTE: compare file name (without path), because iOS is inconsistent about symbolic links at root of documents path
    BOOL modelChanged = NO;

    // Load cache
    NSArray *surveyUrls = [self.items mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        return [obj url];
    }];
    
    // create (in order) surveys from cached urls IFF they are found in the Documents Folder
    [self.items removeAllObjects];
    NSMutableSet *localSurveyFileNames = [SurveyCollection existingPrivateSurveyNames];
    for (NSURL *surveyUrl in surveyUrls) {
        NSString *cachedSurveyFileName = [surveyUrl lastPathComponent];
        if ([localSurveyFileNames containsObject:cachedSurveyFileName]) {
            [self.items addObject:[[Survey alloc] initWithURL:surveyUrl]];
            [localSurveyFileNames removeObject:cachedSurveyFileName];
        }
    }
    if (self.items.count < surveyUrls.count) {
        modelChanged = YES;
    }

    //Add surveys in our private folder that are not in our URL cache
    //This should be impossible now because only the app can add to the private folder.
    //previously we needed this check when the surveys were in the public folder.
    if (surveyUrls.count < self.items.count) {
        AKRLog(@"Whaaat ... Somebody created a private survey without telling me!!!");
    }

    //Add surveys that were added to the public (iTunes) folder;
    //First check for raw (private extensions) surveys.  This will probably only be done by developers.
    //The survey init method will move the survey from the public iTunes folder to the private folder.
    for (NSString *localSurveyFileName in [SurveyCollection existingPublicSurveyNames]) {
        NSURL *surveyUrl = [[SurveyCollection documentsDirectory] URLByAppendingPathComponent:localSurveyFileName];
        [self.items addObject:[[Survey alloc] initWithURL:surveyUrl]];
        modelChanged = YES;
    }

    // I cannot add importable surveys in the public (iTues) folder because they are likely exports.
    // See Issue #90 (https://github.com/regan-sarwas/Observer/issues/90) for a discussion of options.

    if (modelChanged) {
        [self saveCache];
    }
}

+ (NSMutableSet *) /* of NSString */ existingPrivateSurveyNames
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
            if ([SurveyCollection isPrivateURL:url]) {
                [localFileNames addObject:[url lastPathComponent]];
            }
        }
        return [NSMutableSet setWithArray:localFileNames];;
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
            if ([SurveyCollection isPrivateURL:url]) {
                [localFileNames addObject:[url lastPathComponent]];
            }
        }
        return [NSMutableSet setWithArray:localFileNames];;
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
            if ([SurveyCollection isImportURL:url]) {
                [localFileNames addObject:[url lastPathComponent]];
            }
        }
        return [NSMutableSet setWithArray:localFileNames];;
    }
    AKRLog(@"Unable to enumerate %@: %@",[self.documentsDirectory lastPathComponent], error.localizedDescription);
    return nil;
}

+ (NSURL *)documentsDirectory
{
    static NSURL *_documentsDirectory = nil;
    if (!_documentsDirectory) {
        _documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    }
    return _documentsDirectory;
}

@end
