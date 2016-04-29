//
//  MissionTotalizer.m
//  Observer
//
//  Created by Regan Sarwas on 4/26/16.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import "MissionTotalizer.h"
#import "TrackLogSegment.h"

typedef NS_OPTIONS(NSUInteger, TotalizerUnits) {
    TotalizerUnitsKilometers = 0,
    TotalizerUnitsMiles      = 1,
    TotalizerUnitsTime       = 2
};


@interface MissionTotalizer ()

@property (nonatomic, strong, readwrite) NSString *message;
@property (nonatomic, strong, readwrite) SProtocol *protocol;
@property (nonatomic, strong, readwrite) NSMutableArray *trackLogSegments;

@property (nonatomic, strong, readwrite) TrackLogSegment *currentSegment;
@property (nonatomic, strong, readwrite) NSArray *fields;
@property (nonatomic, readwrite) BOOL showOn;
@property (nonatomic, readwrite) BOOL showOff;
@property (nonatomic, readwrite) BOOL showTotal;
@property (nonatomic, readwrite) TotalizerUnits units;

@end

@implementation MissionTotalizer

- (id)initWithProtocol:(SProtocol *)protocol trackLogSegments:(NSMutableArray *)trackLogSegments {
    if (protocol == nil || trackLogSegments == nil) {
        return nil;
    }
    self = [super init];
    if (self != nil) {
        _protocol = protocol;
        _trackLogSegments = trackLogSegments;
        if (![self parseProtocol]) {
            return nil;
        }
    }
    return self;
}

- (void)updateWithLocation:(CLLocation *)location forMissionProperties:(MissionProperty *)missionProperty
{
    [self updateWMessage];
}

- (void)trackLogSegmentsChanged:(NSMutableArray *)trackLogSegments
{
    self.trackLogSegments = trackLogSegments;
    self.currentSegment = (TrackLogSegment *)[self.trackLogSegments lastObject];
    [self updateWMessage];
}

- (void)missionPropertyChanged:(MissionProperty *)missionProperty
{
    [self updateWMessage];
}

- (void)updateWMessage
{
    //_curentSegment.length
    self.message = [NSString stringWithFormat:@"Track %u time: %@", [self.trackLogSegments count], self.timeString];
}

- (NSString *)timeString
{
    NSTimeInterval duration = self.currentSegment.duration;
    if (duration < 60) {
        return [NSString stringWithFormat:@"%0.0f seconds", duration];
    }
    return [NSString stringWithFormat:@"%0.0f minutes", (duration/60.0)];
}

//    ⁃	fields - A required array of field names
//               when any of the fields change, a different total is displayed.
//               There must be at least on field (string) in the array which matches the name of one of the attributes in the mission
//    ⁃	units - An optional element with a value of "kilometers" or "miles" or "minutes". Default is "kilometers"
//    ⁃	includeon - A boolean value (true/false), that indicate is the total while "observing" is true should be displayed.  The default is  true
//    ⁃	includeoff - A boolean value (true/false), that indicate if the total while "observing" is false should be displayed.  The default is  false
//    ⁃	includetotal - A boolean value (true/false), that indicate if the total regardless of "observing" status should be displayed.  The default is  false

- (BOOL)parseProtocol
{
    BOOL hasTotalizer = NO;
    switch (self.protocol.metaversion) {
        case 2:
        {
            NSDictionary *config = self.protocol.totalizerConfig;
            if (config)
            {
                self.showOn = YES;
                if ([config[@"includeon"] isEqual:[NSNumber numberWithBool:NO]]) {
                    self.showOn = NO;
                }
                self.showOff = NO;
                if ([config[@"includeoff"] isEqual:[NSNumber numberWithBool:YES]]) {
                    self.showOff = YES;
                }
                self.showTotal = NO;
                if ([config[@"includetotal"] isEqual:[NSNumber numberWithBool:YES]]) {
                    self.showTotal = YES;
                }
                self.units = TotalizerUnitsKilometers;
                if ([config[@"units"] isEqual:@"miles"]) {
                    self.units = TotalizerUnitsMiles;
                }
                if ([config[@"units"] isEqual:@"minutes"]) {
                    self.units = TotalizerUnitsTime;
                }
                // get and verify fields
                NSMutableArray *tempfields = [NSMutableArray new];
                id protocol_fields = config[@"fields"];
                if ([protocol_fields isKindOfClass:[NSArray class]]) {
                    NSArray *fields = (NSArray *)protocol_fields;
                    for (id protocol_field in fields) {
                        if ([protocol_field isKindOfClass:[NSString class]]) {
                            NSString *field = (NSString *)protocol_field;
                            // look up in self.protocol.missionFeature.attributes and add to array if it exists
                            [tempfields addObject:field];
                        }
                    }
                }
                self.fields = [tempfields copy];

                if ((self.showOn || self.showOff || self.showTotal) && 0 < self.fields.count) {
                    hasTotalizer = YES;
                }
            }
        }
    }
    return hasTotalizer;
}

@end
