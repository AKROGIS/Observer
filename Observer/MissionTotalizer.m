//
//  MissionTotalizer.m
//  Observer
//
//  Created by Regan Sarwas on 4/26/16.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import "MissionTotalizer.h"

@interface MissionTotalizer ()

@property (nonatomic, strong, readwrite) NSString *message;
@property (nonatomic, strong, readwrite) SProtocol *protocol;

@end

@implementation MissionTotalizer

- (id)initWithProtocol:(SProtocol *)protocol
{
    if (self = [super init]) {
        _protocol = protocol;
    }
    return self;
}

- (void)updateWithLocation:(CLLocation *)location forMissionProperties:(MissionProperty *)missionProperty
{
    self.message = [NSString stringWithFormat:@"Updated location @%@",[NSDate date]];
}

- (void)updateWithMissionProperties:(MissionProperty *)missionProperty
{
    self.message = [NSString stringWithFormat:@"Updated mission @%@",[NSDate date]];
}

@end
