//
//  Archiver.m
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Archiver.h"
#import "NSData+CocoaDevUsersAdditions.h"

@implementation Archiver

+ (BOOL)unpackArchive:(NSURL *)importUrl to:(NSURL *)outputUrl {

    NSData *zippedData = [NSData dataWithContentsOfURL:importUrl];

    // Read data into a File/directory Wrapper
    NSData *unzippedData = [zippedData gzipInflate];
    NSFileWrapper *dirWrapper = [[NSFileWrapper alloc] initWithSerializedRepresentation:unzippedData];
    if (dirWrapper == nil) {
        NSLog(@"Error creating dir wrapper from unzipped data");
        return FALSE;
    }

    NSError *error;
    BOOL success = [dirWrapper writeToURL:outputUrl options:NSFileWrapperWritingAtomic originalContentsURL:nil error:&error];
    if (!success) {
        NSLog(@"Error importing file: %@", error.localizedDescription);
        return FALSE;
    }

    return TRUE;
    
}


@end
