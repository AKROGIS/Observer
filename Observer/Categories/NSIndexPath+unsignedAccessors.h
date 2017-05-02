//
//  NSIndexPath+unsignedAccessors.h
//  Observer
//
//  Created by Regan Sarwas on 1/28/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h> //NSIndexSet is in UIKit

@interface NSIndexPath (unsignedAccessors)

@property (nonatomic, readonly) NSUInteger urow;
@property (nonatomic, readonly) NSUInteger usection;

@end
