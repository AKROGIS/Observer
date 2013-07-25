//
//  AGSPointTests.m
//  Observer
//
//  Created by Regan Sarwas on 7/24/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AGSPointTests.h"
#import "AGSPoint+AKRAdditions.h"

@implementation AGSPointTests


- (void)testPositiveAngleDistanceWithUnitsEqualSR
{
    AGSSpatialReference *sr = [[AGSSpatialReference alloc] initWithWKID:3338]; //Alaska Albers
    STAssertEquals(sr.unit, AGSSRUnitMeter, @"SR is not in meters");
    AGSPoint *point = [AGSPoint pointWithX:0 y:0 spatialReference:sr];
    double distance = 100 * M_SQRT2;
    AGSPoint *newPoint = [point pointWithAngle:45 distance:distance units:AGSSRUnitMeter];
    STAssertEqualsWithAccuracy(newPoint.x, 100.0, .00001, @"New X value is not correct");
    STAssertEqualsWithAccuracy(newPoint.y, 100.0, .00001, @"New Y value is not correct");
}

- (void)testPositiveAngleDistanceWithUnitsNotEqualSR
{
    AGSSpatialReference *sr = [[AGSSpatialReference alloc] initWithWKID:3338]; //Alaska Albers
    STAssertEquals(sr.unit, AGSSRUnitMeter, @"SR is not in meters");
    AGSPoint *point = [AGSPoint pointWithX:0 y:0 spatialReference:sr];
    double distance = 100 * M_SQRT2 * 3937.0/1200.0;
    AGSPoint *newPoint = [point pointWithAngle:45 distance:distance units:AGSSRUnitSurveyFoot];
    STAssertEqualsWithAccuracy(newPoint.x, 100.0, .00001, @"New X value is not correct");
    STAssertEqualsWithAccuracy(newPoint.y, 100.0, .00001, @"New Y value is not correct");
}

- (void)testNegativeAngleDistanceWithUnitsEqualSR
{
    AGSSpatialReference *sr = [[AGSSpatialReference alloc] initWithWKID:3338]; //Alaska Albers
    STAssertEquals(sr.unit, AGSSRUnitMeter, @"SR is not in meters");
    AGSPoint *point = [AGSPoint pointWithX:100 y:200 spatialReference:sr];
    double distance = 100 * M_SQRT2;
    AGSPoint *newPoint = [point pointWithAngle:-135.0 distance:distance units:AGSSRUnitMeter];
    STAssertEqualsWithAccuracy(newPoint.x, 0.0, .00001, @"New X value is not correct");
    STAssertEqualsWithAccuracy(newPoint.y, 100.0, .00001, @"New Y value is not correct");
}

- (void)testPositiveAngleDistanceWithNoSR
{
    AGSPoint *point = [AGSPoint pointWithX:10 y:20 spatialReference:nil];
    double distance = 100;
    AGSPoint *newPoint = [point pointWithAngle:45 distance:distance units:AGSSRUnitMeter];
    STAssertFalse(isnan(newPoint.x), @"New X value is Nan");
    STAssertFalse(isnan(newPoint.y), @"New Y value is Nan");
    STAssertEqualsWithAccuracy(newPoint.x, point.x, .00001, @"New X value is not correct");
    STAssertEqualsWithAccuracy(newPoint.y, point.y, .00001, @"New Y value is not correct");
}

- (void)testPositiveAngleDistanceWithSRUnitsMismatch
{
    AGSSpatialReference *sr = [[AGSSpatialReference alloc] initWithWKID:4326]; //WGS84
    STAssertEquals(sr.unit, AGSSRUnitDegree, @"SR is not in geographic");
    AGSPoint *point = [AGSPoint pointWithX:10 y:20 spatialReference:sr];
    double distance = 100;
    AGSPoint *newPoint = [point pointWithAngle:45 distance:distance units:AGSSRUnitMeter];
    STAssertFalse(isnan(newPoint.x), @"New X value is Nan");
    STAssertFalse(isnan(newPoint.y), @"New Y value is Nan");
    STAssertEqualsWithAccuracy(newPoint.x, point.x, .00001, @"New X value is not correct"); //Gives false positive with NaN
    STAssertEqualsWithAccuracy(newPoint.y, point.y, .00001, @"New Y value is not correct");
}


@end
