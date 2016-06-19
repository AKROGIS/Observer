//
//  POGraphic.h
//  Observer
//
//  Created by Regan Sarwas on 2016-06-17.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@interface POGraphic : AGSGraphic

@property (strong, nonatomic) AGSGraphic *label;

@end
