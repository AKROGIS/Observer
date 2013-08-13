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

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testDefaultConstructor
{
    LocationAngleDistance *location = [[LocationAngleDistance alloc] init];
    STAssertEqualsWithAccuracy(location.deadAhead, 0.0, 0.00001, @"deadAhead is not zero");
    STAssertEqualObjects(location.defaultAngle, nil, @"Default Angle is not nil");
    STAssertEqualObjects(location.defaultDistance, nil, @"Default Distance is not nil");
    STAssertEqualObjects(location.angle, nil, @"Angle is not nil");
    STAssertEqualObjects(location.distance, nil, @"Distance is not nil");
    STAssertFalse(location.isComplete, @"Location is complete");
    location.angle = [NSNumber numberWithDouble:45];
    location.distance = [NSNumber numberWithDouble:100];
    STAssertEqualsWithAccuracy(location.absoluteAngle, 45.0, 0.00001, @"Angle is not correct");
    STAssertEqualsWithAccuracy(location.distanceMeters, 100.0, 0.00001, @"Distance is not correct");
    STAssertTrue(location.isComplete, @"Location is not complete");
}

@end
