//
//  AGSPointTests.m
//  Observer
//
//  Created by Regan Sarwas on 7/24/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AGSPoint+AKRAdditions.h"

#import <XCTest/XCTest.h>

@interface AGSPointTests : XCTestCase

@end

@implementation AGSPointTests


- (void)testPositiveAngleDistanceWithUnitsEqualSR
{
    AGSSpatialReference *sr = [[AGSSpatialReference alloc] initWithWKID:3338]; //Alaska Albers
    XCTAssertEqual(sr.unit, AGSSRUnitMeter, @"SR is not in meters");
    AGSPoint *point = [AGSPoint pointWithX:0 y:0 spatialReference:sr];
    double distance = 100 * M_SQRT2;
    AGSPoint *newPoint = [point pointWithAngle:45 distance:distance units:AGSSRUnitMeter];
    XCTAssertEqualWithAccuracy(newPoint.x, 100.0, .00001, @"New X value is not correct");
    XCTAssertEqualWithAccuracy(newPoint.y, 100.0, .00001, @"New Y value is not correct");
}

- (void)testPositiveAngleDistanceWithUnitsNotEqualSR
{
    AGSSpatialReference *sr = [[AGSSpatialReference alloc] initWithWKID:3338]; //Alaska Albers
    XCTAssertEqual(sr.unit, AGSSRUnitMeter, @"SR is not in meters");
    AGSPoint *point = [AGSPoint pointWithX:0 y:0 spatialReference:sr];
    double distance = 100 * M_SQRT2 * 3937.0/1200.0;
    AGSPoint *newPoint = [point pointWithAngle:45 distance:distance units:AGSSRUnitSurveyFoot];
    XCTAssertEqualWithAccuracy(newPoint.x, 100.0, .00001, @"New X value is not correct");
    XCTAssertEqualWithAccuracy(newPoint.y, 100.0, .00001, @"New Y value is not correct");
}

- (void)testNegativeAngleDistanceWithUnitsEqualSR
{
    AGSSpatialReference *sr = [[AGSSpatialReference alloc] initWithWKID:3338]; //Alaska Albers
    XCTAssertEqual(sr.unit, AGSSRUnitMeter, @"SR is not in meters");
    AGSPoint *point = [AGSPoint pointWithX:100 y:200 spatialReference:sr];
    double distance = 100 * M_SQRT2;
    AGSPoint *newPoint = [point pointWithAngle:-135.0 distance:distance units:AGSSRUnitMeter];
    XCTAssertEqualWithAccuracy(newPoint.x, 0.0, .00001, @"New X value is not correct");
    XCTAssertEqualWithAccuracy(newPoint.y, 100.0, .00001, @"New Y value is not correct");
}

- (void)testPositiveAngleDistanceWithNoSR
{
    AGSPoint *point = [AGSPoint pointWithX:10 y:20 spatialReference:nil];
    double distance = 100;
    AGSPoint *newPoint = [point pointWithAngle:45 distance:distance units:AGSSRUnitMeter];
    XCTAssertNil(newPoint, @"Point is not nil");
}

- (void)testPositiveAngleDistanceWithSRUnitsMismatch
{
    //This test will fail if the Spatial Reference is not the same as in AGSPoint+AKRAdditions
    AGSSpatialReference *sr = [[AGSSpatialReference alloc] initWithWKID:3857]; //Web Mercator
    AGSSpatialReference *wgs84 = [[AGSSpatialReference alloc] initWithWKID:4326]; //WGS84
    XCTAssertEqual(sr.unit, AGSSRUnitMeter, @"SR is not in meters");
    XCTAssertEqual(wgs84.unit, AGSSRUnitDegree, @"SR is not in geographic");
    AGSPoint *point = [AGSPoint pointWithX:100 y:200 spatialReference:sr];
    AGSPoint *geoPoint =  (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:point toSpatialReference:wgs84];
    double distance = 100 * M_SQRT2;
    AGSPoint *newGeoPoint = [geoPoint pointWithAngle:-135 distance:distance units:AGSSRUnitMeter];
    AGSPoint *newPoint =  (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:newGeoPoint toSpatialReference:sr];
    XCTAssertEqualWithAccuracy(newPoint.x, 0.0, .00001, @"New X value is not correct");
    XCTAssertEqualWithAccuracy(newPoint.y, 100.0, .00001, @"New Y value is not correct");
}


@end
