//
//  NSURL+isEqualToURL.h
//  Observer
//
//  Created by Regan Sarwas on 7/11/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (isEqualToURL)

// Compares two URLs for equality (i.e. point to the same resource
//  this is trickier than it seems
- (BOOL)isEqualToURL:(NSURL *)other;

@end
