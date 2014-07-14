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

- (NSData *)exportToNSData
{
    NSError *error;
    NSFileWrapper *dirWrapper = [[NSFileWrapper alloc] initWithURL:self.url options:0 error:&error];
    if (dirWrapper == nil) {
        NSLog(@"Error creating directory wrapper: %@", error.localizedDescription);
        return nil;
    }

    NSData *dirData = [dirWrapper serializedRepresentation];
    NSData *gzData = [dirData gzipDeflate];
    return gzData;
}

- (BOOL)exportToDiskWithName:(NSString *)exportPath
{
    NSData *gzData = [self exportToNSData];
    if (gzData == nil) return FALSE;
    [gzData writeToFile:exportPath atomically:YES];
    return TRUE;
    
}

- (BOOL)exportToDiskWithForce:(BOOL)force
{
    NSString *name = [self getExportFileName];
    NSString *exportPath = [[self.documentsDirectory URLByAppendingPathComponent:name] path];

    // Check if file already exists (unless we force the write)
    if (!force && [[NSFileManager defaultManager] fileExistsAtPath:exportPath]) {
        return FALSE;
    }

    return [self exportToDiskWithName:exportPath];
}

- (NSURL *)documentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
}

@end
