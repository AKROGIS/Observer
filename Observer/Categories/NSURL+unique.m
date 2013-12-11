//
//  NSURL+unique.m
//  Observer
//
//  Created by Regan Sarwas on 11/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "NSURL+unique.h"

@implementation NSURL (unique)

- (NSURL *)URLByUniquingPath
{
    if (!self.isFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:[self path]])
        return self;

    int i = 1;
    NSURL *directory = [self URLByDeletingLastPathComponent];
    NSString *originalName = [self.lastPathComponent stringByDeletingPathExtension];
    NSString *extension = [self pathExtension];

    NSURL *newURL;
    do {
        NSString *newName = [NSString stringWithFormat:@"%@-%d.%@",originalName,i++,extension];
        newURL = [directory URLByAppendingPathComponent:newName];
    } while ([[NSFileManager defaultManager] fileExistsAtPath:[newURL path]]);
    return newURL;
}

@end
