//
//  Map.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Map : NSObject

+ (Map *) randomMap; //for testing purposes

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *summary;

@end
