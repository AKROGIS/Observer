//
//  MissionTotalizer.m
//  Observer
//
//  Created by Regan Sarwas on 4/26/16.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import "MissionTotalizer.h"
#import "TrackLogSegment.h"
#import "NSArray+map.h"
#import "CommonDefines.h"

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
@property (nonatomic, readwrite) NSString *unitLabel;
@property (nonatomic, readwrite) NSString *names;
@property (nonatomic, readwrite) NSString *joinedValues;
@property (nonatomic, readwrite) double priorOnTotal;
@property (nonatomic, readwrite) double priorOffTotal;

@end

@implementation MissionTotalizer

- (id)initWithProtocol:(SProtocol *)protocol trackLogSegments:(NSMutableArray *)trackLogSegments {
    if (protocol == nil || trackLogSegments == nil) {
        return nil;
    }
    self = [super init];
    if (self != nil) {
        _protocol = protocol;
        if (![self parseProtocol]) {
            return nil;
        }
        [self trackLogSegmentsChanged:trackLogSegments];
    }
    return self;
}



- (void)updateWithLocation:(CLLocation *)location forMissionProperties:(MissionProperty *)missionProperty
{
    [self updateMessage];
}

- (void)trackLogSegmentsChanged:(NSMutableArray *)trackLogSegments
{
    self.trackLogSegments = trackLogSegments;
    self.currentSegment = (TrackLogSegment *)[self.trackLogSegments lastObject];
    [self updateFieldValues];
    [self updatePriorTotals];
    [self updateMessage];
}

- (void)missionPropertyChanged:(MissionProperty *)missionProperty
{
    [self updateFieldValues];
    [self updatePriorTotals];
    [self updateMessage];
}



- (void)updateFieldValues
{
    NSMutableArray *values = [self.fields mapObjectsUsingBlock:^id(NSAttributeDescription *obj, NSUInteger idx) {
        return [NSString stringWithFormat:@"%@", [self.currentSegment.missionProperty valueForKey:obj.name]];
    }];
    self.joinedValues = [values componentsJoinedByString:@";"];
}

- (void)updatePriorTotals
{
    self.priorOnTotal = 0;
    self.priorOffTotal = 0;
    NSUInteger length = self.trackLogSegments.count;
    if (length < 1) return;
    for (TrackLogSegment *segment in [self.trackLogSegments subarrayWithRange:NSMakeRange(0, length-1)]) {
        if ([self isMatchingSegment:segment]) {
            if (segment.missionProperty.observing) {
                if (self.units == TotalizerUnitsTime) {
                    self.priorOnTotal += segment.duration;
                } else {
                    self.priorOnTotal += segment.length;
                }
            } else {
                if (self.units == TotalizerUnitsTime) {
                    self.priorOffTotal += segment.duration;
                } else {
                    self.priorOffTotal += segment.length;
                }
            }
        }
    }
}

- (BOOL)isMatchingSegment:(TrackLogSegment *)segment
{
    for (NSAttributeDescription *attribute in self.fields) {
        NSString *key = attribute.name;
        id currentValue = [self.currentSegment.missionProperty valueForKey:key];
        id segmentValue = [segment.missionProperty valueForKey:key];
        if (!currentValue && !segmentValue) {
            // nil and nil is a match, even though it fails equality
            //Good so far, check next attribute
            continue;
        }
        if ([currentValue isEqual:segmentValue]) {
            //Good so far, check next attribute
            continue;
        }
        return NO;
    }
    return YES;
}

- (void)updateMessage
{
    //TODO: combine with buildMessage and do case logic first to short circuit some work when only on or off is required
    double onTotal = self.priorOnTotal;
    double offTotal = self.priorOffTotal;
    double value = 0;
    if (self.units == TotalizerUnitsTime) {
        value = self.currentSegment.duration;
    } else {
        value = self.currentSegment.length;
    }
    if (self.currentSegment.missionProperty.observing) {
        onTotal += value;
    } else {
        offTotal += value;
    }
    //Convert from meters or seconds
    if (self.units == TotalizerUnitsMiles) {
        onTotal = onTotal/1609.34;  //1200.0*5280.0/3937.0;
        offTotal = offTotal/1609.34;
    }
    if (self.units == TotalizerUnitsKilometers) {
        onTotal = onTotal/1000.0;
        offTotal = offTotal/1000.0;
    }
    if (self.units == TotalizerUnitsTime) {
        onTotal = onTotal/60.0;
        offTotal = offTotal/60.0;
    }
    double totalTotal = onTotal + offTotal;
    self.message = [self buildMessageOn:onTotal off:offTotal total:totalTotal];
}

-(NSString *)buildMessageOn:(double)on off:(double)off total:(double)total
{
    NSString *message = nil;
    if (self.showOn && self.showOff && self.showTotal)
    {
        message = [NSString stringWithFormat:@"%0.1f on + %0.1f off in %0.1f %@ for %@ %@",on, off, total, self.unitLabel, self.names, self.joinedValues];
    } else
        if (self.showOn && self.showOff)
    {
        message = [NSString stringWithFormat:@"%0.1f on + %0.1f off %@ for %@ %@",on, off, self.unitLabel, self.names, self.joinedValues];
    } else
        if (self.showOn && self.showTotal)
    {
        message = [NSString stringWithFormat:@"%0.1f on in %0.1f %@ for %@ %@", on, total, self.unitLabel, self.names, self.joinedValues];
    } else
        if (self.showOff && self.showTotal)
    {
        message = [NSString stringWithFormat:@"%0.1f off in %0.1f %@ for %@ %@", off, total, self.unitLabel, self.names, self.joinedValues];
    } else
        if (self.showTotal)
    {
        message = [NSString stringWithFormat:@"%0.1f %@ total for %@ %@", total, self.unitLabel, self.names, self.joinedValues];
    } else
        if (self.showOff)
    {
        message = [NSString stringWithFormat:@"%0.1f %@ off %@ %@", off, self.unitLabel, self.names, self.joinedValues];
    } else
        if (self.showOn)
    {
        message = [NSString stringWithFormat:@"%0.1f %@ on %@ %@", on, self.unitLabel, self.names, self.joinedValues];
    }
    return message;
}

- (BOOL)parseProtocol
{
    // From the Protocol Specifications:
    //    ⁃	fields - A required array of field names
    //    ⁃	units - An optional element with a value of "kilometers" or "miles" or "minutes". Default is "kilometers"
    //    ⁃	includeon - A boolean value (true/false), that indicate is the total while "observing" is true should be displayed.  The default is  true
    //    ⁃	includeoff - A boolean value (true/false), that indicate if the total while "observing" is false should be displayed.  The default is  false
    //    ⁃	includetotal - A boolean value (true/false), that indicate if the total regardless of "observing" status should be displayed.  The default is  false

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
                self.unitLabel = @"Kms";
                if ([config[@"units"] isEqual:@"miles"]) {
                    self.units = TotalizerUnitsMiles;
                    self.unitLabel = @"Miles";
                }
                if ([config[@"units"] isEqual:@"minutes"]) {
                    self.units = TotalizerUnitsTime;
                    self.unitLabel = @"Minutes";
                }
                // get and verify fields
                NSMutableArray *tempfields = [NSMutableArray new];
                id protocol_fields = config[@"fields"];
                if ([protocol_fields isKindOfClass:[NSArray class]]) {
                    NSArray *fields = (NSArray *)protocol_fields;
                    for (id protocol_field in fields) {
                        if ([protocol_field isKindOfClass:[NSString class]]) {
                            NSString *field = (NSString *)protocol_field;
                            NSString *obscuredField = [NSString stringWithFormat:@"%@%@",kAttributePrefix,field];
                            // look up in self.protocol.missionFeature.attributes and add to array if it exists
                            for (NSAttributeDescription *attribute in self.protocol.missionFeature.attributes) {
                                if ([obscuredField isEqualToString:attribute.name]) {
                                    if (!self.names) {
                                        self.names = field;
                                    } else {
                                        self.names = [NSString stringWithFormat:@"%@;%@", self.names, field];
                                    }
                                    [tempfields addObject:attribute];
                                }
                            }
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
