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
    NSString *path = self.path;
    BOOL pathExists = (path == nil) ? NO : [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!self.isFileURL || !pathExists)
        return self;

    int i = 1;
    NSURL *directory = self.URLByDeletingLastPathComponent;
    NSString *originalName = (self.lastPathComponent).stringByDeletingPathExtension;
    NSString *extension = self.pathExtension;

    NSURL *newURL;
    NSString *newPath = nil;
    BOOL newPathExists = YES; //Assume it exists; It will get set in loop before real check
    do {
        NSString *newName = [NSString stringWithFormat:@"%@-%d.%@",originalName,i++,extension];
        newURL = [directory URLByAppendingPathComponent:newName];
        newPath = newURL.path;
        newPathExists = (newPath == nil) ? NO : [[NSFileManager defaultManager] fileExistsAtPath:newPath];
    } while (newPath == nil || newPathExists);
    return newURL;
}

@end
