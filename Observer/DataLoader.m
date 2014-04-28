//
//  DataLoader.m
//  Observer
//
//  Created by Regan Sarwas on 4/25/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "DataLoader.h"
#import "SProtocol.h"
#import "Survey.h"
#import "SurveyCoreDataDocument.h"
#import "ObserverModel.h"
#import "AKRFormatter.h"

#define kProtocolName  @"kimu.obsprot"
#define kGpsData       @"kimu_gps.csv"
#define kTrackData     @"kimu_tracks.csv"
#define kBirdData      @"kimu_birds.csv"

@interface DataLoader ()
@property (strong, nonatomic) Mission *mission;
@property (strong, nonatomic) Survey *survey;
@property (strong, nonatomic) NSDate *lastTimestamp;
@end

@implementation DataLoader

- (void)loadData
{
    SProtocol *protocol = [[SProtocol alloc] initWithURL:[[DataLoader documentsDirectory] URLByAppendingPathComponent:kProtocolName]];
    self.survey = [[Survey alloc] initWithProtocol:protocol];
    [self.survey openDocumentWithCompletionHandler:^(BOOL success) {
        if (success) {
            [self loadDocument];
            AKRLog(@"Document Loaded");
        } else {
            AKRLog(@"Unable to load document");
        }
    }];
}

- (void) loadDocument
{
    NSManagedObjectContext *context = _survey.document.managedObjectContext;
    [self loadGPS:context from:[[DataLoader documentsDirectory] URLByAppendingPathComponent:kGpsData]];
    [self loadTracks:context from:[[DataLoader documentsDirectory] URLByAppendingPathComponent:kTrackData]];
    [self loadBirds:context from:[[DataLoader documentsDirectory] URLByAppendingPathComponent:kBirdData]];
    [self.survey closeDocumentWithCompletionHandler:^(BOOL success) {
        AKRLog(@"Document is closed");
    }];
}

- (void)loadGPS:(NSManagedObjectContext *)context from:(NSURL *)url
{
    AKRLog(@"Loading GPS points");
    NSString* fileContents = [NSString stringWithContentsOfFile:[url path] encoding:NSUTF8StringEncoding error:nil];
    NSArray* allLines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in allLines) {
        if (line.length < 10) continue; //if the line ends with \r\n, then everyother line will be empty
        NSArray *items = [line componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
        [self createGpsPoint:context from:items];
    }
}

- (void)loadTracks:(NSManagedObjectContext *)context from:(NSURL *)url
{
    AKRLog(@"Loading Tracks");
    NSString* fileContents = [NSString stringWithContentsOfFile:[url path] encoding:NSUTF8StringEncoding error:nil];
    NSArray* allLines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in allLines) {
        if (line.length < 10) continue; //if the line ends with \r\n, then everyother line will be empty
        NSArray *items = [line componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
        [self createMissionProperty:context from:items];
    }
}

- (void)loadBirds:(NSManagedObjectContext *)context from:(NSURL *)url
{
    AKRLog(@"Loading Birds");
    NSString* fileContents = [NSString stringWithContentsOfFile:[url path] encoding:NSUTF8StringEncoding error:nil];
    NSArray* allLines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in allLines) {
        if (line.length < 10) continue; //if the line ends with \r\n, then everyother line will be empty
        NSArray *items = [line componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
        [self createAdHocObservation:context from:items];
    }
}

- (void)createGpsPoint:(NSManagedObjectContext *)context from:(NSArray *)item
{
    //NOTE!! Our GPS data input file must be in timestamp order
    //item string[] = Lat_dd,Long_dd,Time_utc,HDOP,Satellite_count,Speed,Bearing,GPS_Fix_Status

    if (item.count < 8) {
        AKRLog(@"Not enough items for a GPS point");
        return;
    }
    NSDate *timestamp = [AKRFormatter datetimeFromISOString:item[2]];
    NSAssert(timestamp, @"Oh No!, we don't have a GPS timestamp for %@", item[2]);

    BOOL longInterval = self.lastTimestamp ? (300 /*seconds*/ < [timestamp timeIntervalSinceDate:self.lastTimestamp]) : YES;

    //Start a new mission if we don't have one, or it has been 5 minutes since the last GPS point
    if (longInterval || !self.mission) {
        self.mission = [NSEntityDescription insertNewObjectForEntityForName:kMissionEntityName inManagedObjectContext:context];
    }
    NSAssert(self.mission, @"We do not have a mission in Core Data at %@", timestamp);

    GpsPoint *gpsPoint = [NSEntityDescription insertNewObjectForEntityForName:kGpsPointEntityName inManagedObjectContext:context];
    NSAssert(gpsPoint, @"Could not create a Gps Point in Core Data at %@", timestamp);
    gpsPoint.mission = self.mission;
    gpsPoint.altitude =[(NSString *)item[7] doubleValue];
    gpsPoint.course = [(NSString *)item[6] doubleValue];
    gpsPoint.horizontalAccuracy = [(NSString *)item[3] doubleValue];
    gpsPoint.latitude = [(NSString *)item[0] doubleValue];
    gpsPoint.longitude = [(NSString *)item[1] doubleValue];
    gpsPoint.speed = [(NSString *)item[5] doubleValue];
    gpsPoint.timestamp = timestamp;
    gpsPoint.verticalAccuracy = [(NSString *)item[4] doubleValue];
    self.lastTimestamp = timestamp;
}

- (void)createMissionProperty:(NSManagedObjectContext *)context from:(NSArray *)item
{
    //Vessel,Recorder,Observer1,Observer2,Visibility,Weather,Beaufort,TransectID,Protocol_ID,OnTransect,time_utc

    if (item.count < 11) {
        AKRLog(@"Not enough items for a Track log");
        return;
    }

    NSDate *timestamp = [AKRFormatter datetimeFromISOString:item[10]];
    NSAssert(timestamp, @"Oh No!, we don't have a track timestamp for %@", item[10]);
    GpsPoint *gpsPoint = [self gpsPointInContext:context atTimestamp:timestamp];
    NSAssert(gpsPoint, @"Could not find the gps point for tracklog at %@", timestamp);

    MissionProperty *missionProperty = [NSEntityDescription insertNewObjectForEntityForName:kMissionPropertyEntityName inManagedObjectContext:context];
    NSAssert(missionProperty, @"Could not create a Mission Property for %@", timestamp);
    missionProperty.mission = gpsPoint.mission;
    missionProperty.gpsPoint = gpsPoint;
    missionProperty.observing = [item[9] isEqualToString:@"TRUE"];
    [missionProperty setValue:item[7] forKey:@"A_Transect"];
    [missionProperty setValue:item[0] forKey:@"A_Vessel"];
    [missionProperty setValue:item[1] forKey:@"A_Recorder"];
    [missionProperty setValue:item[2] forKey:@"A_Observer1"];
    [missionProperty setValue:item[3] forKey:@"A_Observer2"];
    //[missionProperty setValue:item[7] forKey:@"A_ProtocolId"];
    [missionProperty setValue:[NSNumber numberWithInteger:[(NSString *)item[5] integerValue]] forKey:@"A_Weather"];
    [missionProperty setValue:[NSNumber numberWithInteger:[(NSString *)item[4] integerValue]] forKey:@"A_Visibility"];
    [missionProperty setValue:[NSNumber numberWithInteger:[(NSString *)item[6] integerValue]] forKey:@"A_Beaufort"];
}

- (void)createAdHocObservation:(NSManagedObjectContext *)context from:(NSArray *)item
{
    //wk,wm,wp,wu,fk,fm,fp,fu,Comments,Angle,Distance,Time_utc

    if (item.count < 12) {
        AKRLog(@"Not enough items for a bird group");
        return;
    }

    NSDate *timestamp = [AKRFormatter datetimeFromISOString:item[11]];
    NSAssert(timestamp, @"Oh No!, we don't have a bird timestamp for %@", item[11]);
    GpsPoint *gpsPoint = [self gpsPointInContext:context atTimestamp:timestamp];
    NSAssert(gpsPoint, @"Could not find the gps point for bird group at %@", timestamp);

    AngleDistanceLocation *angleDistance = [NSEntityDescription insertNewObjectForEntityForName:kAngleDistanceLocationEntityName inManagedObjectContext:context];
    NSAssert(angleDistance, @"Could not create an AngleDistanceLocation for %@", timestamp);
    angleDistance.angle = [(NSString *)item[9] doubleValue];
    angleDistance.distance = [(NSString *)item[10] doubleValue];
    angleDistance.direction = 180.0; //Well known fact for this protocol

    Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"O_BirdGroups" inManagedObjectContext:context];
    observation.gpsPoint = gpsPoint;
    observation.mission = gpsPoint.mission;
    observation.angleDistanceLocation = angleDistance;
    [observation setValue:[NSNumber numberWithInteger:[(NSString *)item[0] integerValue]] forKey:@"A_countWaterKitlitz"];
    [observation setValue:[NSNumber numberWithInteger:[(NSString *)item[1] integerValue]] forKey:@"A_countWaterMarbled"];
    [observation setValue:[NSNumber numberWithInteger:[(NSString *)item[2] integerValue]] forKey:@"A_countWaterPending"];
    [observation setValue:[NSNumber numberWithInteger:[(NSString *)item[3] integerValue]] forKey:@"A_countWaterUnknown"];
    [observation setValue:[NSNumber numberWithInteger:[(NSString *)item[4] integerValue]] forKey:@"A_countFlyingKitlitz"];
    [observation setValue:[NSNumber numberWithInteger:[(NSString *)item[5] integerValue]] forKey:@"A_countFlyingMarbled"];
    [observation setValue:[NSNumber numberWithInteger:[(NSString *)item[6] integerValue]] forKey:@"A_countFlyingPending"];
    [observation setValue:[NSNumber numberWithInteger:[(NSString *)item[7] integerValue]] forKey:@"A_countFlyingUnknown"];
    //[observation setValue:[NSNumber numberWithInteger:[(NSString *)item[8] integerValue]] forKey:@"A_comments"];
}

- (GpsPoint *)gpsPointInContext:(NSManagedObjectContext *)context atTimestamp:(NSDate *)timestamp
{
    //Deal with ESRI graphic date bug
    NSDate *start = [timestamp dateByAddingTimeInterval:-0.01];
    NSDate *end = [timestamp dateByAddingTimeInterval:+0.01];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"(%@ <= timestamp AND timestamp <= %@)",start,end];
    NSArray *results = [context executeFetchRequest:request error:nil];
    return (GpsPoint *)[results lastObject]; // will return nil if there was an error, or no results
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
