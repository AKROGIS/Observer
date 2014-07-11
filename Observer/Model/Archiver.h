//
//  Archiver.h
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Archiver : NSObject

+ (BOOL)unpackArchive:(NSURL *)importUrl to:(NSURL *)outputUrl;

@end
