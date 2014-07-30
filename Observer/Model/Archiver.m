//
//  Archiver.m
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Archiver.h"
#import "NSData+CocoaDevUsersAdditions.h"
#import <ZipKit/ZipKit.h>

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

+ (NSData *)exportURL:(NSURL *)url toNSDataError:(NSError * __autoreleasing *)error
{
    NSFileWrapper *dirWrapper = [[NSFileWrapper alloc] initWithURL:url options:0 error:error];
    if (!dirWrapper) {
        return nil;
    }
    return [[dirWrapper serializedRepresentation] gzipDeflate];
}

+ (BOOL)exportURL:(NSURL *)url toDiskWithName:(NSString *)exportPath error:(NSError * __autoreleasing *)error
{
    NSData *gzData = [self exportURL:url toNSDataError:error];
    if (gzData == nil) return NO;
    if ([gzData writeToFile:exportPath atomically:YES]) {
        return YES;
    } else {
        if (error != NULL) {
            //User wants error details, lets give it to them.
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"Unable to write to filesystem." forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"observer.nps.gov" code:100 userInfo:details];
        }
        return NO;
    }
}


@end
