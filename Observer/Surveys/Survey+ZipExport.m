//
//  Survey+ZipExport.m
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Survey+ZipExport.h"
#import "NSData+CocoaDevUsersAdditions.h"

@implementation Survey (ZipExport)

- (NSString *)getExportFileName {
    return [NSString stringWithFormat:@"%@.%@", self.title, SURVEY_EXT];
}

- (NSData *)exportToNSDataError:(NSError * __autoreleasing *)error
{
    NSFileWrapper *dirWrapper = [[NSFileWrapper alloc] initWithURL:self.url options:0 error:error];
    if (!dirWrapper) {
        return nil;
    }
    return [[dirWrapper serializedRepresentation] gzipDeflate];
}

- (BOOL)exportToDiskWithName:(NSString *)exportPath error:(NSError * __autoreleasing *)error
{
    NSData *gzData = [self exportToNSDataError:error];
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

- (BOOL)exportToDiskWithForce:(BOOL)force error:(NSError * __autoreleasing *)error
{
    NSString *name = [self getExportFileName];
    NSString *exportPath = [[self.documentsDirectory URLByAppendingPathComponent:name] path];

    // Check if file already exists (unless we force the write)
    if (!force && [[NSFileManager defaultManager] fileExistsAtPath:exportPath]) {
        return FALSE;
    }

    return [self exportToDiskWithName:exportPath error:error];
}

- (NSURL *)documentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
}

@end
