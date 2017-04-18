//
//  POGraphic.h
//  Observer
//
//  Created by Regan Sarwas on 2016-06-17.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>
#import "Observation.h"
#import "Survey.h"

@interface POGraphic : AGSGraphic

@property (strong, nonatomic) AGSGraphic *label;

- (AGSGraphic *)redraw:(Observation *)observation survey:(Survey *)survey;

- (void)remove;

@end
