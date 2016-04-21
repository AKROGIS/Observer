//
//  Survey+ZipExport.m
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Survey+ZipExport.h"
#import "Archiver.h"

@implementation Survey (ZipExport)

- (NSString *)getExportFileName {
    return [NSString stringWithFormat:@"%@.%@", self.title, SURVEY_EXT];
}

- (NSData *)exportToNSDataError:(NSError * __autoreleasing *)error
{
    return [Archiver exportURL:self.url withCSVfromSurvey:self toNSDataError:error];
}

- (BOOL)exportToDiskWithForce:(BOOL)force error:(NSError * __autoreleasing *)error
{
    NSString *name = [self getExportFileName];
    NSString *exportPath = [[self.documentsDirectory URLByAppendingPathComponent:name] path];

    // Check if file already exists (unless we force the write)
    if (!force && [[NSFileManager defaultManager] fileExistsAtPath:exportPath]) {
        return FALSE;
    }

    return [Archiver exportURL:self.url withCSVfromSurvey:self toDiskWithName:exportPath error:error];
}

- (NSURL *)documentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
}

@end
