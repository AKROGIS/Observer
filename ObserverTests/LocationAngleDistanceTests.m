//
//  LocationAngleDistanceTests.m
//  Observer
//
//  Created by Regan Sarwas on 8/12/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "LocationAngleDistance.h"
#import "ProtocolFeature.h"

#import <XCTest/XCTest.h>

@interface LocationAngleDistanceTests : XCTestCase

@end

@implementation LocationAngleDistanceTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testDefaultConstructorWithDefaultProtocol
{
    NSDictionary *json = nil;
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:feature];
    XCTAssertEqualWithAccuracy(location.deadAhead, 0.0, 0.00001, @"deadAhead is not zero");
    XCTAssertEqualObjects(location.defaultAngle, nil, @"Default Angle is not nil");
    XCTAssertEqualObjects(location.defaultDistance, nil, @"Default Distance is not nil");
    XCTAssertEqualObjects(location.angle, nil, @"Angle is not nil");
    XCTAssertEqualObjects(location.distance, nil, @"Distance is not nil");
    XCTAssertFalse(location.isComplete, @"Location is complete");
    location.angle = [NSNumber numberWithDouble:45];
    location.distance = [NSNumber numberWithDouble:100];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 45.0, 0.00001, @"Angle is not correct");
    XCTAssertEqualWithAccuracy(location.distanceMeters, 100.0, 0.00001, @"Distance is not correct");
    XCTAssertTrue(location.isComplete, @"Location is not complete");
}

- (void)testDefaultConstructorWithAtypicalProtocol1
{
    NSDictionary *json = @{@"name"      : @"test",
                           @"locations" : @[@{@"type":@"angleDistance", @"units":@"feet"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:feature];

    //double feet = 100.0*3937.0/1200.0; //100meters in survey feet
    double feet = 100.0/(0.0254*12.0); //100meters in international feet
    location.distance = [NSNumber numberWithDouble:feet];
    XCTAssertEqualWithAccuracy(location.distanceMeters, 100.0, 0.00001, @"Distance is not correct");
}

- (void)testDefaultConstructorWithAtypicalProtocol2
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@90.0, @"direction":@"cw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:feature];

    XCTAssertEqualWithAccuracy(location.deadAhead, 0.0, 0.00001, @"deadAhead is not zero");
    location.angle = [NSNumber numberWithDouble:30];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 300.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:110];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 20.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:-30];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 240.0, 0.00001, @"Angle is not correct");
}

- (void)testDefaultConstructorWithAtypicalProtocol3
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@90.0, @"direction":@"ccw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:feature];

    XCTAssertEqualWithAccuracy(location.deadAhead, 0.0, 0.00001, @"deadAhead is not zero");
    location.angle = [NSNumber numberWithDouble:30];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 60.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:110];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:-30];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
}

- (void)testConstructorWithCourseAndDefaultProtocol
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@180.0, @"units":@"meter", @"direction":@"ccw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:100.0 protocolFeature:feature];

    XCTAssertEqualWithAccuracy(location.deadAhead, 100.0, 0.00001, @"deadAhead is not zero");
    location.angle = [NSNumber numberWithDouble:160];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:-200];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:-560];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:200];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 80.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:300];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:660];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
    location.angle = [NSNumber numberWithDouble:1020];
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
}

- (void)testFullConstructorWithDefaultProtocol
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@0.0, @"units":@"meter", @"direction":@"cw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:feature absoluteAngle:30 distance:100];

    XCTAssertEqualObjects(location.distance, [NSNumber numberWithDouble:100], @"Distance is not correct");
    XCTAssertEqualObjects(location.defaultDistance, [NSNumber numberWithDouble:100], @"Default Distance is not correct");
    XCTAssertEqualWithAccuracy(location.distanceMeters, 100.0, 0.00001, @"Absolute Distance is not correct");
    XCTAssertEqualObjects(location.angle, [NSNumber numberWithDouble:30], @"Angle is not correct");
    XCTAssertEqualObjects(location.defaultAngle, [NSNumber numberWithDouble:30], @"Default Angle is not correct");
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 30.0, 0.00001, @"Absolute Angle is not correct");
    location.distance = [NSNumber numberWithDouble:200];
    location.angle = [NSNumber numberWithDouble:-30];
    XCTAssertEqualObjects(location.distance, [NSNumber numberWithDouble:200], @"Distance is not correct");
    XCTAssertEqualObjects(location.defaultDistance, [NSNumber numberWithDouble:100], @"Default Distance is not correct");
    XCTAssertEqualWithAccuracy(location.distanceMeters, 200.0, 0.00001, @"Absolute Distance is not correct");
    XCTAssertEqualObjects(location.angle, [NSNumber numberWithDouble:-30], @"Angle is not correct");
    XCTAssertEqualObjects(location.defaultAngle, [NSNumber numberWithDouble:30], @"Default Angle is not correct");
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 330.0, 0.00001, @"Absolute Angle is not correct");
}

- (void)testFullConstructorWithAtypicalProtocol1
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@180.0, @"units":@"feet", @"direction":@"ccw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:feature absoluteAngle:30 distance:100];

    //double feet = 100.0*3937.0/1200.0; //100meters in survey feet
    double feet = 100.0/(0.0254*12.0); //100meters in international feet
    //XCTAssertEqualObjects(location.distance, [NSNumber numberWithDouble:feet], @"Distance is not correct"); //can't reliably compare doubles
    XCTAssertEqualWithAccuracy([location.distance doubleValue], feet, 0.00001, @"Distance is not correct");
    XCTAssertEqualWithAccuracy(location.distanceMeters, 100.0, 0.00001, @"Distance is not correct");
//    location.protocol.distanceUnits = AGSSRUnitMeter;
//    //XCTAssertEqualObjects(location.distance, [NSNumber numberWithDouble:feet], @"Distance is not correct"); //can't reliably compare doubles
//    XCTAssertEqualWithAccuracy([location.distance doubleValue], feet, 0.00001, @"Distance is not correct");
//    XCTAssertEqualWithAccuracy(location.distanceMeters, feet, 0.00001, @"Distance is not correct");
}

- (void)testFullConstructorWithAtypicalProtocol2
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@90.0, @"units":@"meter", @"direction":@"cw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:10.0 protocolFeature:feature absoluteAngle:50 distance:100];

    XCTAssertEqualWithAccuracy(location.deadAhead, 10.0, 0.00001, @"deadAhead is not zero");
    XCTAssertEqualObjects(location.angle, [NSNumber numberWithDouble:130], @"Angle is not correct");
    XCTAssertEqualWithAccuracy(location.absoluteAngle,50.0, 0.00001, @"Absolute Angle is not correct");
//    location.protocol.angleBaseline = 60.0;
//    location.protocol.angleDirection = AngleDirectionCounterClockwise;
//    XCTAssertEqualWithAccuracy(location.deadAhead, 10.0, 0.00001, @"deadAhead is not zero");
//    XCTAssertEqualObjects(location.angle, [NSNumber numberWithDouble:130], @"Angle is not correct");
//    XCTAssertEqualWithAccuracy(location.absoluteAngle,300.0, 0.00001, @"Absolute Angle is not correct");
}

@end
