//
//  Survey.m
//  Observer
//
//  Created by Regan Sarwas on 12/3/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "Survey.h"
#import "NSURL+unique.h"
#import "NSDate+Formatting.h"
#import "ObserverModel.h"

#define kCodingVersion    1
#define kCodingVersionKey @"codingversion"
#define kUrlKey           @"url"
#define kSTitleKey        @"title"
#define kStateKey         @"state"
#define kDateKey          @"date"

#define kPropertiesFilename @"properties.plist"
#define kProtocolFilename   @"protocol.obsprot"
#define kThumbnailFilename  @"thumbnail.png"
#define kDocumentFilename   @"survey.coredata"

@interface Survey ()

@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, readwrite) SurveyState state;
@property (nonatomic, strong, readwrite) NSDate *date;
@property (nonatomic, strong, readwrite) UIImage *thumbnail;
@property (nonatomic, strong, readwrite) SProtocol *protocol;
@property (nonatomic, strong, readwrite) UIManagedDocument *document;
@property (nonatomic, strong) NSURL *propertiesUrl;
@property (nonatomic, strong) NSURL *thumbnailUrl;
@property (nonatomic, strong) NSURL *protocolUrl;
@property (nonatomic, strong) NSURL *documentUrl;
@property (nonatomic) BOOL protocolIsLoaded;
@property (nonatomic) BOOL thumbnailIsLoaded;
@property (nonatomic) BOOL documentIsLoaded;

@end

@implementation Survey

#pragma mark - initializers

- (id)initWithURL:(NSURL *)url title:(NSString *)title state:(SurveyState)state date:(NSDate *)date
{
    if (self = [super init]) {
        _url = url;
        _state = state;
        _date = date;
        _title = title;
        _protocolIsLoaded = NO;
        _thumbnailIsLoaded = NO;
    }
    return self;
}

- (id)initWithURL:(NSURL *)url
{
    return [self initWithURL:url title:nil state:kUnborn date:[NSDate date]];
}

- (id)initWithProtocol:(SProtocol *)protocol
{
    //verify the input - reading protocol values may cause protocol to load from filesystem
    if (!protocol.isValid) {
        return nil;
    }
    //find a suitable URL (reads filesystem)
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSString *filename = [NSString stringWithFormat:@"%@.%@", protocol.title, SURVEY_EXT];
    //the trailing slash is added because it is a directory, and this standardizes the URL for comparisons
    NSURL *url = [[[documentsDirectory URLByAppendingPathComponent:filename] URLByUniquingPath] URLByAppendingPathComponent:@"/"];
    NSString *title = [[url lastPathComponent] stringByDeletingPathExtension];
    self = [self initWithURL:url title:title state:kCreated date:[NSDate date]];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:nil]) {
        return nil;
    };
    if (![protocol saveCopyToURL:self.protocolUrl]) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        return nil;
    }
    [self saveProperties];
    return self;
}


#pragma mark property accessors

@synthesize title = _title;

- (NSString *)title
{
    if (self.state == kUnborn) {
        [self loadProperties];
    }
    return _title;
}

- (void)setTitle:(NSString *)title
{
    if (_title != title) {
        _title = title;
        [self saveProperties];
        //TODO: we should also rename the URL, to simiplify recognition in transfers
    }
}

- (NSDate *)date
{
    if (self.state == kUnborn) {
        [self loadProperties];
    }
    return _date;
}

- (NSString *)subtitle
{
    return [NSString stringWithFormat:@"Protocol: %@, v. %@",self.protocol.title, self.protocol.version];
}

- (NSString *)subtitle2
{
    NSString *status = nil;
    switch (self.state) {
        case kUnborn:
            status = @"Unborn";
            break;
        case kCorrupt:
            status = @"Corrupt";
            break;
        case kCreated:
            status = @"Created";
            break;
        case kModified:
            status = @"Modified";
            break;
        case kSaved:
            status = @"Saved";
            break;
        default:
            status = @"Unknown State";
            break;
    }
    return [NSString stringWithFormat:@"%@: %@",status, [self.date stringWithMediumDateTimeFormat]];
}

- (UIImage *)thumbnail
{
    if (!_thumbnail && !self.thumbnailIsLoaded) {
        [self loadThumbnail];
    }
    return _thumbnail;
}

- (SProtocol *)protocol
{
    if (!_protocol && !self.protocolIsLoaded) {
        [self loadProtocol];
    }
    return _protocol;
}

- (NSURL *)propertiesUrl
{
    if (!_propertiesUrl) {
        _propertiesUrl = [self.url URLByAppendingPathComponent:kPropertiesFilename];
    }
    return _propertiesUrl;
}

- (NSURL *)thumbnailUrl
{
    if (!_thumbnailUrl) {
        _thumbnailUrl = [self.url URLByAppendingPathComponent:kThumbnailFilename];
    }
    return _thumbnailUrl;
}

- (NSURL *)protocolUrl
{
    if (!_protocolUrl) {
        _protocolUrl = [self.url URLByAppendingPathComponent:kProtocolFilename];
    }
    return _protocolUrl;
}

- (NSURL *)documentUrl
{
    if (!_documentUrl) {
        _documentUrl = [self.url URLByAppendingPathComponent:kDocumentFilename];
    }
    return _documentUrl;
}

#pragma mark - public methods

- (BOOL)isEqualToSurvey:(Survey *)survey
{
    //Comparing URLs is tricky, I am trying to be efficient, and permissive
    return ([self.url isEqual:survey.url] ||
            [self.url.absoluteURL isEqual:survey.url.absoluteURL] ||
            [self.url.fileReferenceURL isEqual:survey.url.fileReferenceURL]);
}

- (BOOL) isValid
{
    //TODO: improve this method
    return self.protocol != nil;
}

//TODO: figure out error handling.
//TODO: this public method isn't used - justify the API or remove
- (void)readPropertiesWithCompletionHandler:(void (^)(NSError*))handler
{
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer",DISPATCH_QUEUE_CONCURRENT), ^{
        if (![self loadProperties]) {
            self.state = kCorrupt;
        }
        [self loadProtocol];
        [self loadThumbnail];
        NSError *error;
        if (self.state == kCorrupt) {
            NSMutableDictionary* errorDetails = [NSMutableDictionary dictionary];
            [errorDetails setValue:@"Survey File is corrupt" forKey:NSLocalizedDescriptionKey];
            // populate the error object with the details
            error = [NSError errorWithDomain:@"gov.nps.akr.observer" code:1 userInfo:errorDetails];
        }
        if (handler) handler(error);
    });
}

- (void)openDocumentWithCompletionHandler:(void (^)(BOOL success))handler
{
    dispatch_async(dispatch_queue_create("gov.nps.akr.observer",DISPATCH_QUEUE_CONCURRENT), ^{
        //during development, it is possible that a previously valid protocol is no longer recognized as valid
        //we might be able to remove this check in production code.
        if (!self.protocol.isValid) {
            self.state = kCorrupt;
        }
        if (self.state == kCorrupt) {
            if (handler) handler(NO);
        } else {
            self.document = [[SurveyCoreDataDocument alloc] initWithFileURL:self.documentUrl];
            BOOL documentExists = [[NSFileManager defaultManager] fileExistsAtPath:[self.documentUrl path]];
            if (documentExists) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.document openWithCompletionHandler:handler];  //fails unless executed on UI thread
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.document saveToURL:self.documentUrl forSaveOperation:UIDocumentSaveForCreating completionHandler:handler];
                });
            }
        }
    });
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(objectsDidChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:self.document.managedObjectContext];
#ifdef DEBUG
    [self connectToNotificationCenter];
#endif
}

- (void)closeDocumentWithCompletionHandler:(void (^)(BOOL success))completionHandler
{
#ifdef DEBUG
    AKRLog(@"Closing document");
    [self logStats];
    [self disconnectFromNotificationCenter];
#endif
    [self.document closeWithCompletionHandler:completionHandler];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)syncWithCompletionHandler:(void (^)(NSError*))handler
{
    //TODO: Implement
    self.date = [NSDate date];
    self.state = kSaved;
}


#pragma mark - private methods

- (BOOL)loadProperties
{
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfURL:self.propertiesUrl];
    NSInteger version = [plist[kCodingVersionKey] integerValue];
    switch (version) {
        case 1:
            _title = plist[kSTitleKey];
            _state = [plist[kStateKey] unsignedIntegerValue];
            _date = plist[kDateKey];
            return YES;
        default:
            return NO;
    }
}

- (BOOL)loadProtocol
{
    self.protocolIsLoaded = YES;
    _protocol = [[SProtocol alloc] initWithURL:self.protocolUrl];
    if (!_protocol.isValid) {
        self.state = kCorrupt;
        _protocol = nil;
        return NO;
    }
    return YES;
}

- (BOOL)loadThumbnail
{
    self.thumbnailIsLoaded = YES;
    _thumbnail = [[UIImage alloc] initWithContentsOfFile:[self.thumbnailUrl path]];
    if (!_thumbnail)
        _thumbnail = [UIImage imageNamed:@"SurveyDoc"];
    return !_thumbnail;
}


- (void)documentChanged:(id)sender {
    self.state = kModified;
    self.date = [NSDate date];
    [self saveProperties];
    //TODO: build new thumbnail and save;
}

- (BOOL)saveProperties {
    //TODO: omit null values from the dictionary, and then check for missing keys on load
    if (!self.title || !self.date) {
        return NO;
    }
    NSDictionary *plist = @{kCodingVersionKey:@kCodingVersion,
                            kSTitleKey:self.title,
                            kStateKey:@(self.state),
                            kDateKey:self.date};
    return [plist writeToURL:self.propertiesUrl atomically:YES];
}

- (BOOL)saveThumbnail
{
    return [UIImagePNGRepresentation(self.thumbnail) writeToFile:[self.thumbnailUrl path] atomically:YES];
}


- (void)objectsDidChange:(NSNotification *)notification
{
#ifdef DEBUG
    AKRLog(@"Survey.document.managedObjectContext objects did change.");
#endif
    self.date = [NSDate date];
    self.state = kModified;
    //do not save properties (write a file to disk) here, since this is called a lot - do it when coredata saves
}

- (NSString *)description
{
    if (self.state == kUnborn) {
        return @"Unborn survey (properties not yet loaded from disk)";
    } else {
        return [NSString stringWithFormat:@"%@; %@; %@", self.title, self.subtitle2, self.protocolIsLoaded ? self.subtitle : @"protocol not yet loaded"];
    }
}

#pragma mark - Diagnostic aids - remove when done

#ifdef DEBUG

- (void) connectToNotificationCenter
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(documentStateChanged:)
                                                 name:UIDocumentStateChangedNotification
                                               object:self.document];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dataChanged:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:self.document.managedObjectContext];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dataSaved:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:self.document.managedObjectContext];
}

- (void) disconnectFromNotificationCenter
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDocumentStateChangedNotification
                                                  object:self.document];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextObjectsDidChangeNotification
                                                  object:self.document.managedObjectContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:self.document.managedObjectContext];
}

- (void) documentStateChanged: (NSNotification *)notification
{
    //name should always be UIDocumentStateChangedNotification
    //object should always be self.document
    //userinfo is nil

    AKRLog(@"Document (%@) state changed", self.title);
    switch (self.document.documentState) {
        case UIDocumentStateNormal:
            AKRLog(@"  Document is normal");
            break;
        case UIDocumentStateClosed:
            AKRLog(@"  Document is closed");
            break;
        case UIDocumentStateEditingDisabled:
            AKRLog(@"  Document editing is disabled");
            break;
        case UIDocumentStateInConflict:
            AKRLog(@"  Document is in conflict");
            break;
        case UIDocumentStateSavingError:
            AKRLog(@"  Document has an error saving state");
            break;
        default:
            AKRLog(@"  Document has an unexpected state: %d",self.document.documentState);
    }
}

- (void) dataChanged: (NSNotification *)notification
{
    //name should always be NSManagedObjectContextObjectsDidChangeNotification
    //object should always be self.document
    //userinfo has keys NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey which all return arrays of objects

    AKRLog(@"Document (%@) data changed", self.title);
    //AKRLog(@"Data Changed; \nname:%@ \nobject:%@ \nuserinfo:%@", notification.name, notification.object, notification.userInfo);
}

- (void) dataSaved: (NSNotification *)notification
{
    //name should always be NSManagedObjectContextDidSaveNotification
    //object should always be self.document
    //userinfo has keys NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey which all return arrays of objects

    AKRLog(@"Document (%@) data saved", self.title);
    //AKRLog(@"Data Saved; \nname:%@ \nobject:%@ \nuserinfo:%@", notification.name, notification.object, notification.userInfo);
    [self saveProperties];
}

- (void)logStats
{
    AKRLog(@"  Survey (%@) contains:", self.title);
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
    NSArray *results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d GpsPoints", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kObservationEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d Observations", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kMissionPropertyEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d MissionProperties", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kMissionEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d Missions", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kMapEntityName];
    results = [self.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"    %d Maps", results.count);
}

#endif

@end
