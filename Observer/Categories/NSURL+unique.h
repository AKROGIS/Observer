//
//  NSURL+unique.h
//  Observer
//
//  Created by Regan Sarwas on 11/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (unique)

// Does nothing is url is not a file url
// otherwise, does nothing if the there is no file existing at the path,
// otherwise mutates the last path component until the path is unique.
// NOTE: the path may no longer be unique when the caller uses the url
- (NSURL *)URLByUniquingPath;

@end
