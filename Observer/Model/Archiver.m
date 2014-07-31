//
//  Archiver.m
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Archiver.h"
#import <ZipKit/ZipKit.h>

@implementation Archiver

+ (BOOL)unpackArchive:(NSURL *)importUrl to:(NSURL *)outputUrl {

    ZKDataArchive *archive = [ZKDataArchive archiveWithArchivePath:importUrl.path];
    NSString *parentFolder = [[[outputUrl URLByDeletingLastPathComponent] filePathURL] path];
    NSString *folder = outputUrl.lastPathComponent;
    NSUInteger errorCode = [archive inflateInFolder:parentFolder withFolderName:folder usingResourceFork:NO];
    if (errorCode == (NSUInteger)zkSucceeded) {
        return YES;
    } else {
        NSLog(@"Error inflating zip at:%@ to %@", importUrl, outputUrl);
        return NO;
    };
}

+ (NSData *)exportURL:(NSURL *)url toNSDataError:(NSError * __autoreleasing *)error
{
    NSData *data = nil;
    if ([url isFileURL]) {
        NSString *path = url.path;
        BOOL isDir;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        if (exists) {
            ZKDataArchive *archive = [ZKDataArchive new];
            if (isDir) {
                [archive deflateDirectory:path relativeToPath:[path stringByDeletingLastPathComponent] usingResourceFork:NO];
            } else {
                [archive deflateFile:path relativeToPath:[path stringByDeletingLastPathComponent] usingResourceFork:NO];
            }
            data = archive.data;
        }
    }
    return data;
}

+ (BOOL)exportURL:(NSURL *)url toDiskWithName:(NSString *)exportPath error:(NSError * __autoreleasing *)error
{
    NSData *data = [self exportURL:url toNSDataError:error];
    if (data == nil) return NO;
    if ([data writeToFile:exportPath atomically:YES]) {
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
