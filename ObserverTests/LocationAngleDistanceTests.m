//
//  LocationAngleDistanceTests.m
//  Observer
//
//  Created by Regan Sarwas on 8/12/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "LocationAngleDistanceTests.h"
#import "LocationAngleDistance.h"

@implementation LocationAngleDistanceTests

LocationAngleDistance *_location;
SurveyProtocol *_protocol;

- (void)setUp
{
    [super setUp];
    _protocol = [[SurveyProtocol alloc] init];
    _protocol.distanceUnits = AGSSRUnitMeter;
    _protocol.angleBaseline = 0;
    _protocol.angleDirection = AngleDirectionClockwise;
    _protocol.definesAngleDistanceMeasures = YES;
    _location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocol:_protocol];
}

- (void)tearDown
{
    _protocol = nil;
    _location = nil;
    [super tearDown];
}

- (void)testDefaultConstructorWithDefaultProtocol
{
    STAssertEqualsWithAccuracy(_location.deadAhead, 0.0, 0.00001, @"deadAhead is not zero");
    STAssertEqualObjects(_location.defaultAngle, nil, @"Default Angle is not nil");
    STAssertEqualObjects(_location.defaultDistance, nil, @"Default Distance is not nil");
    STAssertEqualObjects(_location.angle, nil, @"Angle is not nil");
    STAssertEqualObjects(_location.distance, nil, @"Distance is not nil");
    STAssertFalse(_location.isComplete, @"Location is complete");
    _location.angle = [NSNumber numberWithDouble:45];
    _location.distance = [NSNumber numberWithDouble:100];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 45.0, 0.00001, @"Angle is not correct");
    STAssertEqualsWithAccuracy(_location.distanceMeters, 100.0, 0.00001, @"Distance is not correct");
    STAssertTrue(_location.isComplete, @"Location is not complete");
}

- (void)testDefaultConstructorWithAtypicalProtocol1
{
    _location.protocol.distanceUnits = AGSSRUnitFoot;
    //double feet = 100.0*3937.0/1200.0; //100meters in survey feet
    double feet = 100.0/(0.0254*12.0); //100meters in international feet
    _location.distance = [NSNumber numberWithDouble:feet];
    STAssertEqualsWithAccuracy(_location.distanceMeters, 100.0, 0.00001, @"Distance is not correct");
}

- (void)testDefaultConstructorWithAtypicalProtocol2
{
    _location.protocol.angleBaseline = 90.0;
    _location.protocol.angleDirection = AngleDirectionClockwise;
    STAssertEqualsWithAccuracy(_location.deadAhead, 0.0, 0.00001, @"deadAhead is not zero");
    _location.angle = [NSNumber numberWithDouble:30];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 300.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:110];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 20.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:-30];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 240.0, 0.00001, @"Angle is not correct");
}

- (void)testDefaultConstructorWithAtypicalProtocol3
{
    _location.protocol.angleBaseline = 90.0;
    _location.protocol.angleDirection = AngleDirectionCounterClockwise;
    STAssertEqualsWithAccuracy(_location.deadAhead, 0.0, 0.00001, @"deadAhead is not zero");
    _location.angle = [NSNumber numberWithDouble:30];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 60.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:110];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:-30];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
}

- (void)testConstructorWithCourseAndDefaultProtocol
{
    _location = [[LocationAngleDistance alloc] initWithDeadAhead:100.0 protocol:_protocol];
    _location.protocol.distanceUnits = AGSSRUnitMeter;
    _location.protocol.angleBaseline = 180.0;
    _location.protocol.angleDirection = AngleDirectionCounterClockwise;
    STAssertEqualsWithAccuracy(_location.deadAhead, 100.0, 0.00001, @"deadAhead is not zero");
    _location.angle = [NSNumber numberWithDouble:160];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:-200];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:-560];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:200];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 80.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:300];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:660];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
    _location.angle = [NSNumber numberWithDouble:1020];
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
}

- (void)testFullConstructorWithDefaultProtocol
{
    _protocol.distanceUnits = AGSSRUnitMeter;
    _protocol.angleBaseline = 0;
    _protocol.angleDirection = AngleDirectionClockwise;
    _location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocol:_protocol absoluteAngle:30 distance:100];
    STAssertEqualObjects(_location.distance, [NSNumber numberWithDouble:100], @"Distance is not correct");
    STAssertEqualObjects(_location.defaultDistance, [NSNumber numberWithDouble:100], @"Default Distance is not correct");
    STAssertEqualsWithAccuracy(_location.distanceMeters, 100.0, 0.00001, @"Absolute Distance is not correct");
    STAssertEqualObjects(_location.angle, [NSNumber numberWithDouble:30], @"Angle is not correct");
    STAssertEqualObjects(_location.defaultAngle, [NSNumber numberWithDouble:30], @"Default Angle is not correct");
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 30.0, 0.00001, @"Absolute Angle is not correct");
    _location.distance = [NSNumber numberWithDouble:200];
    _location.angle = [NSNumber numberWithDouble:-30];
    STAssertEqualObjects(_location.distance, [NSNumber numberWithDouble:200], @"Distance is not correct");
    STAssertEqualObjects(_location.defaultDistance, [NSNumber numberWithDouble:100], @"Default Distance is not correct");
    STAssertEqualsWithAccuracy(_location.distanceMeters, 200.0, 0.00001, @"Absolute Distance is not correct");
    STAssertEqualObjects(_location.angle, [NSNumber numberWithDouble:-30], @"Angle is not correct");
    STAssertEqualObjects(_location.defaultAngle, [NSNumber numberWithDouble:30], @"Default Angle is not correct");
    STAssertEqualsWithAccuracy(_location.absoluteAngle, 330.0, 0.00001, @"Absolute Angle is not correct");
}

- (void)testFullConstructorWithAtypicalProtocol1
{
    _location.protocol.distanceUnits = AGSSRUnitFoot;
    //double feet = 100.0*3937.0/1200.0; //100meters in survey feet
    double feet = 100.0/(0.0254*12.0); //100meters in international feet
    _location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocol:_protocol absoluteAngle:30 distance:100];
    //STAssertEqualObjects(_location.distance, [NSNumber numberWithDouble:feet], @"Distance is not correct"); //can't reliably compare doubles
    STAssertEqualsWithAccuracy([_location.distance doubleValue], feet, 0.00001, @"Distance is not correct");
    STAssertEqualsWithAccuracy(_location.distanceMeters, 100.0, 0.00001, @"Distance is not correct");
    _location.protocol.distanceUnits = AGSSRUnitMeter;
    //STAssertEqualObjects(_location.distance, [NSNumber numberWithDouble:feet], @"Distance is not correct"); //can't reliably compare doubles
    STAssertEqualsWithAccuracy([_location.distance doubleValue], feet, 0.00001, @"Distance is not correct");
    STAssertEqualsWithAccuracy(_location.distanceMeters, feet, 0.00001, @"Distance is not correct");
}

- (void)testFullConstructorWithAtypicalProtocol2
{
    _location.protocol.angleBaseline = 90.0;
    _location.protocol.angleDirection = AngleDirectionClockwise;
    _location = [[LocationAngleDistance alloc] initWithDeadAhead:10.0 protocol:_protocol absoluteAngle:50 distance:100];
    STAssertEqualsWithAccuracy(_location.deadAhead, 10.0, 0.00001, @"deadAhead is not zero");
    STAssertEqualObjects(_location.angle, [NSNumber numberWithDouble:130], @"Angle is not correct");
    STAssertEqualsWithAccuracy(_location.absoluteAngle,50.0, 0.00001, @"Absolute Angle is not correct");
    _location.protocol.angleBaseline = 60.0;
    _location.protocol.angleDirection = AngleDirectionCounterClockwise;
    STAssertEqualsWithAccuracy(_location.deadAhead, 10.0, 0.00001, @"deadAhead is not zero");
    STAssertEqualObjects(_location.angle, [NSNumber numberWithDouble:130], @"Angle is not correct");
    STAssertEqualsWithAccuracy(_location.absoluteAngle,300.0, 0.00001, @"Absolute Angle is not correct");
}

@end
