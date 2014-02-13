//
//  AddFeatureBarButtonItem.h
//  Observer
//
//  Created by Regan Sarwas on 2/12/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ProtocolFeature.h"
#import "Enumerations.h"

@interface AddFeatureBarButtonItem : UIBarButtonItem

@property (strong, nonatomic) ProtocolFeature *feature;

@end
