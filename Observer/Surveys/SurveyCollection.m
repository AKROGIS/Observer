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
@property (nonatomic) BOOL isLoading;
@property (nonatomic) BOOL isLoaded;
@property (nonatomic) NSUInteger selectedIndex;  //NSNotFound -> NO item is selected
@property (nonatomic, strong) NSURL *documentsDirectory;

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

- (void) setSelectedIndex:(NSUInteger)selectedIndex
{
    if (_selectedIndex == selectedIndex)
        return;
    if (self.items.count <= selectedIndex && selectedIndex != NSNotFound) {
        return; //ignore bogus indexes
    }
    _selectedIndex = selectedIndex;
    [Settings manager].indexOfCurrentSurvey = selectedIndex;
}

- (NSURL *)documentsDirectory
{
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
    //Check and set of isLoading must be done on the main thread to guarantee there is no race condition.
    if (self.isLoaded) {
        if (completionHandler)
            completionHandler(self.items != nil);
    } else {
        if (self.isLoading) {
            //wait until loading is completed, then return;
            dispatch_async(dispatch_queue_create("gov.nps.akr.observer.surveycollection.open", DISPATCH_QUEUE_SERIAL), ^{
                //This task is serial with the task that will clear isLoading, so it will not run until loading is done;
                if (completionHandler) {
                    completionHandler(self.items != nil);
                }
            });
        }
        self.isLoading = YES;
        dispatch_async(dispatch_queue_create("gov.nps.akr.observer.surveycollection.open", DISPATCH_QUEUE_SERIAL), ^{
            [self loadAndCorrectListOfSurveys];
            //TODO: consider opening all/selected survey item(s) in the background
            self.isLoaded = YES;
            self.isLoading = NO;
            if (completionHandler) {
                completionHandler(self.items != nil);
            }
        });
    }
}

- (Survey *)surveyForURL:(NSURL *)url
{
    NSUInteger index = [self.items indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [url isEqual:[obj url]];
    }];
    return (index == NSNotFound) ? nil : [self.items objectAtIndex:index];
}

//TODO: test opening a Survey document
- (BOOL)openURL:(NSURL *)url
{
    //The only known use of this is by the app delegate to give us a file in the inbox
    //however, I will make it as generic as possible
    
    //If we already have the url, then do nothing.
    if ([self surveyForURL:url]) {
        return YES;
    }
    NSURL *newUrl = [self.documentsDirectory URLByAppendingPathComponent:[url lastPathComponent]];
    //If the url is already in the documents directory then do not move it
    if (![newUrl isEqual:url]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[newUrl path]]) {
            newUrl = [newUrl URLByUniquingPath];
        }
        if (![[NSFileManager defaultManager] moveItemAtURL:url toURL:newUrl error:nil]) {
            return NO;
        }
    }
    Survey *newSurvey = [[Survey alloc] initWithURL:newUrl];
    if (newSurvey.protocol) {
        NSUInteger index = 0;     //insert at top of list
        [self.items insertObject:newSurvey atIndex:index];
        if (self.selectedIndex != NSNotFound) {
            self.selectedIndex++;
        }
        [self saveCache];
        return YES;
    } else {
        return NO;
    }
}

- (NSUInteger)newSurveyWithProtocol:(SProtocol *)protocol {
    Survey *newSurvey = [[Survey alloc] initWithProtocol:protocol];
    if (newSurvey) {
        NSUInteger index = 0;     //insert at top of list
        [self.items insertObject:newSurvey atIndex:index];
        if (self.selectedIndex != NSNotFound) {
            self.selectedIndex++;
        }
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

-(void)removeSurveyAtIndex:(NSUInteger)index
{
    if (self.items.count <= index) return; //safety check
    Survey *item = [self surveyAtIndex:index];
    //TODO: if the document is open, close it first, or set it to nil, so subsequent attempts to close it do not generate errors.
    [[NSFileManager defaultManager] removeItemAtURL:item.url error:nil];
    [self.items removeObjectAtIndex:index];
    [self saveCache];
    if (index == self.selectedIndex) {
        self.selectedIndex = NSNotFound;
    }
    if (index < self.selectedIndex  && self.selectedIndex != NSNotFound) {
        self.selectedIndex--;
    }
}

-(void)moveSurveyAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (self.items.count <= fromIndex || self.items.count <= toIndex) return;  //safety check
    if (fromIndex == toIndex)
        return;

    //adjust the selected Index
    if (self.selectedIndex != NSNotFound) {
        if (self.selectedIndex == fromIndex) {
            self.selectedIndex = toIndex;
        } else {
            if (fromIndex < self.selectedIndex && self.selectedIndex <= toIndex) {
                self.selectedIndex--;
            } else {
                if (toIndex <= self.selectedIndex && self.selectedIndex < fromIndex) {
                    self.selectedIndex++;
                }
            }
        }
    }

    //move the item
    id temp = self.items[fromIndex];
    [self.items removeObjectAtIndex:fromIndex];
    [self.items insertObject:temp atIndex:toIndex];
    [self saveCache];
}

- (void)setSelectedSurvey:(NSUInteger)index
{
    self.selectedIndex = index;
}

- (Survey *)selectedSurvey
{
    if (self.selectedIndex == NSNotFound || self.items.count == 0 || self.items.count <= self.selectedIndex) {
        return nil;
    }
    return self.items[self.selectedIndex];
}



#pragma mark - private methods

- (void) loadAndCorrectListOfSurveys
{
    BOOL cacheWasOutdated = NO;
    NSArray *cachedSurveyUrls = [Settings manager].surveys;
    
    // create (in order) surveys from urls saved in defaults IFF they are found in filesystem
    NSMutableSet *files = [NSMutableSet setWithArray:[self surveysInDocumentsFolder]];
    for (NSURL *url in cachedSurveyUrls) {
        if ([files containsObject:url]) {
            [self.items addObject:[[Survey alloc] initWithURL:url]];
            [files removeObject:url];
        }
    }
    if (self.items.count < cachedSurveyUrls.count) {
        cacheWasOutdated = YES;
    }

    //Add any other Surveys in filesystem (maybe added via iTunes) to end of list from cached list
    for (NSURL *url in files) {
        [self.items addObject:[[Survey alloc] initWithURL:url]];
        cacheWasOutdated = YES;
    }

    //Get the selected index (we can't do this in an accessor, because there isn't a no valid 'data not loaded' sentinal)
    _selectedIndex = [Settings manager].indexOfCurrentSurvey;

    if (cacheWasOutdated) {
        [self saveCache];
        //Need to validate/fix the selected index (if files were added or deleted, it may not be valid)
        if (self.selectedIndex != NSNotFound && self.selectedIndex < cachedSurveyUrls.count) {
            NSURL *url = cachedSurveyUrls[self.selectedIndex];
            NSUInteger index = [self.items indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [url isEqual:((Survey *)obj).url];
            }];
            self.selectedIndex = index;
        } else {
            self.selectedIndex = NSNotFound;
        }
    }
}

- (NSArray *) /* of NSURL */ surveysInDocumentsFolder
{
    NSMutableArray *localUrls = [[NSMutableArray alloc] init];
    NSArray *documents = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtURL:self.documentsDirectory
                          includingPropertiesForKeys:nil
                          options:NSDirectoryEnumerationSkipsHiddenFiles
                          error:nil];
    if (documents) {
        for (NSURL *url in documents) {
            if ([SurveyCollection collectsURL:url]) {
                [localUrls addObject:url];
            }
        }
    }
    return localUrls;
}


- (void)saveCache
{
    [Settings manager].surveys = [self.items mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        return [obj url];
    }];
}

@end
