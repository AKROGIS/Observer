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
    location.angle = @45.0;
    location.distance = @100.0;
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
    location.distance = @(feet);
    XCTAssertEqualWithAccuracy(location.distanceMeters, 100.0, 0.00001, @"Distance is not correct");
}

- (void)testDefaultConstructorWithAtypicalProtocol2
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@90.0, @"direction":@"cw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:feature];

    XCTAssertEqualWithAccuracy(location.deadAhead, 0.0, 0.00001, @"deadAhead is not zero");
    location.angle = @30.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 300.0, 0.00001, @"Angle is not correct");
    location.angle = @110.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 20.0, 0.00001, @"Angle is not correct");
    location.angle = @-30.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 240.0, 0.00001, @"Angle is not correct");
}

- (void)testDefaultConstructorWithAtypicalProtocol3
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@90.0, @"direction":@"ccw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:feature];

    XCTAssertEqualWithAccuracy(location.deadAhead, 0.0, 0.00001, @"deadAhead is not zero");
    location.angle = @30.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 60.0, 0.00001, @"Angle is not correct");
    location.angle = @110.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
    location.angle = @-30.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
}

- (void)testConstructorWithCourseAndDefaultProtocol
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@180.0, @"units":@"meter", @"direction":@"ccw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:100.0 protocolFeature:feature];

    XCTAssertEqualWithAccuracy(location.deadAhead, 100.0, 0.00001, @"deadAhead is not zero");
    location.angle = @160.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
    location.angle = @-200.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
    location.angle = @-560.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 120.0, 0.00001, @"Angle is not correct");
    location.angle = @200.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 80.0, 0.00001, @"Angle is not correct");
    location.angle = @300.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
    location.angle = @660.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
    location.angle = @1020.0;
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 340.0, 0.00001, @"Angle is not correct");
}

- (void)testFullConstructorWithDefaultProtocol
{
    NSDictionary *json = @{@"name":@"test",
                           @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@0.0, @"units":@"meter", @"direction":@"cw"}]};
    ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:feature absoluteAngle:30 distance:100];

    XCTAssertEqualObjects(location.distance, @100.0, @"Distance is not correct");
    XCTAssertEqualObjects(location.defaultDistance, @100.0, @"Default Distance is not correct");
    XCTAssertEqualWithAccuracy(location.distanceMeters, 100.0, 0.00001, @"Absolute Distance is not correct");
    XCTAssertEqualObjects(location.angle, @30.0, @"Angle is not correct");
    XCTAssertEqualObjects(location.defaultAngle, @30.0, @"Default Angle is not correct");
    XCTAssertEqualWithAccuracy(location.absoluteAngle, 30.0, 0.00001, @"Absolute Angle is not correct");
    location.distance = @200.0;
    location.angle = @-30.0;
    XCTAssertEqualObjects(location.distance, @200.0, @"Distance is not correct");
    XCTAssertEqualObjects(location.defaultDistance, @100.0, @"Default Distance is not correct");
    XCTAssertEqualWithAccuracy(location.distanceMeters, 200.0, 0.00001, @"Absolute Distance is not correct");
    XCTAssertEqualObjects(location.angle, @-30.0, @"Angle is not correct");
    XCTAssertEqualObjects(location.defaultAngle, @30.0, @"Default Angle is not correct");
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
    XCTAssertEqualObjects(location.angle, @130.0, @"Angle is not correct");
    XCTAssertEqualWithAccuracy(location.absoluteAngle,50.0, 0.00001, @"Absolute Angle is not correct");
//    location.protocol.angleBaseline = 60.0;
//    location.protocol.angleDirection = AngleDirectionCounterClockwise;
//    XCTAssertEqualWithAccuracy(location.deadAhead, 10.0, 0.00001, @"deadAhead is not zero");
//    XCTAssertEqualObjects(location.angle, [NSNumber numberWithDouble:130], @"Angle is not correct");
//    XCTAssertEqualWithAccuracy(location.absoluteAngle,300.0, 0.00001, @"Absolute Angle is not correct");
}

- (void)testRoundTrip
{
    NSArray *directions = @[@"ccw", @"cw"];
    int ai;
    int bi;
    int hi;
    int min;
    int max;
    double a;
    double h;
    double aa;
    double b1;
    double b2;
    NSDictionary *json;
    LocationAngleDistance *location;
    LocationAngleDistance *location2;
    
    for (NSString *dir in directions) {
        for (ai = 0; ai <= 180; ai += 90 ) {  // dead ahead in protocol
            a = (double)ai;
            json = @{@"name":@"test", @"locations":@[@{@"type":@"angleDistance", @"deadAhead":@(a), @"units":@"meter", @"direction":dir}]};
            ProtocolFeature *feature = [[ProtocolFeature alloc] initWithJSON:json version:1];
            for (hi = 0; h <= 360; hi += 30) {  // vehicle gps heading
                h = (double)hi;
                location = [[LocationAngleDistance alloc] initWithDeadAhead:h protocolFeature:feature];
                min = ai - 180;
                max = ai + 180;
                for (bi = min; bi <= max; bi += 30) {  //Angle to bird group relative to vehicle heading
                    b1 = (double)bi;
                    if (bi == min) b1 += 0.1;  // because of wrapping, min and max are indistinguishable and they cause false-positives
                    if (bi == max) b1 -= 0.1;
                    location.angle = @(b1);
                    aa = location.absoluteAngle;
                    location2 = [[LocationAngleDistance alloc] initWithDeadAhead:h protocolFeature:feature absoluteAngle:aa distance:100.0];
                    b2 = [location2.angle doubleValue];
                    //NSLog(@"%6.1f > %6.1f > %6.1f %@, deadahead = %.1f, bearing = %.1f", b1, aa, b2, dir, a, h);
                    XCTAssertEqualWithAccuracy(b1, b2, 0.00001, @"Angle did not round trip %@, %f, %f", dir, a, h);
                }
            }
        }
    }
}

@end
