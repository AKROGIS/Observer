//
//  TrackLogSegment.h
//  Observer
//
//  Created by Regan Sarwas on 5/15/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MissionProperty.h"
#import "SProtocol.h"

@interface TrackLogSegment : NSObject

@property (nonatomic, strong) MissionProperty *missionProperty;
@property (nonatomic, strong) NSMutableArray *gpsPoints;

+ (NSString *)csvHeaderForProtocol:(SProtocol *)protocol;

- (NSString *)asCsvForProtocol:(SProtocol *)protocol;

- (AGSPolyline *)polyline;

@end
