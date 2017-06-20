//
//  MissionTotalizer.h
//  Observer
//
//  Created by Regan Sarwas on 4/26/16.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import "MissionProperty.h"
#import "SProtocol.h"

@interface MissionTotalizer : NSObject

- (instancetype)initWithProtocol:(SProtocol *)protocol trackLogSegments:(NSMutableArray *)trackLogSegments  NS_DESIGNATED_INITIALIZER;
- (instancetype)init __attribute__((unavailable("Must use initWithProtocol:trackLogSegments: instead.")));

@property (nonatomic, strong, readonly) SProtocol *protocol;
@property (nonatomic, strong, readonly) NSMutableArray *trackLogSegments;
@property (nonatomic, strong, readonly) NSString *message;
@property (nonatomic, readonly) CGFloat fontSize;


- (void)updateWithLocation:(CLLocation *)location forMissionProperties:(MissionProperty *)missionProperty;
- (void)trackLogSegmentsChanged:(NSMutableArray *)trackLogSegments;
- (void)missionPropertyChanged:(MissionProperty *)missionProperty;

@end
