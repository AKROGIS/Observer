//
//  MissionTotalizer.h
//  Observer
//
//  Created by Regan Sarwas on 4/26/16.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SProtocol.h"
#import "ObserverModel.h"

@interface MissionTotalizer : NSObject

- (id)initWithProtocol:(SProtocol *)protocol trackLogSegments:(NSMutableArray *)trackLogSegments ;

@property (nonatomic, strong, readonly) SProtocol *protocol;
@property (nonatomic, strong, readonly) NSMutableArray *trackLogSegments;
@property (nonatomic, strong, readonly) NSString *message;

- (void)updateWithLocation:(CLLocation *)location forMissionProperties:(MissionProperty *)missionProperty;
- (void)trackLogSegmentsChanged:(NSMutableArray *)trackLogSegments;
- (void)missionPropertyChanged:(MissionProperty *)missionProperty;

@end
