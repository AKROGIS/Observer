//
//  POGraphic.m
//  Observer
//
//  Created by Regan Sarwas on 2016-06-17.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import "POGraphic.h"

@implementation POGraphic

- (AGSGraphic *)redraw:(Observation *)observation survey:(Survey *)survey
{
    [self remove];
    return [survey drawObservation:observation];
}

- (void)remove
{
    [self.graphicsOverlay.graphics removeObject:self];
    [self.label.graphicsOverlay.graphics removeObject:self.label];
}

@end
