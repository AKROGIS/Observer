//
//  NSIndexSet+indexPath.h
//  Observer
//
//  Created by Regan Sarwas on 11/27/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h> //NSIndexSet is in UIKit

@interface NSIndexSet (indexPath)

- (NSArray *)indexPathsWithSection:(NSUInteger)section; //of IndexPaths

@end
