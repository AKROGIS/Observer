//
//  Enumerations.h
//  Observer
//
//  Created by Regan Sarwas on 7/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#ifndef Observer_Enumerations_h
#define Observer_Enumerations_h


typedef NS_ENUM(NSUInteger, AngleDirection) {
    AngleDirectionClockwise         = 0,
    AngleDirectionCounterClockwise  = 1
};

typedef NS_OPTIONS(NSUInteger, WaysToLocateFeature) {
    LocateFeatureWithGPS           = 1<<0,
    LocateFeatureWithAngleDistance = 1<<1,
    LocateFeatureWithMapTouch      = 1<<2,
    LocateFeatureWithMapTarget     = 1<<3
};

#endif
