//
//  Survey+ZipExport.h
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Survey.h"

@interface Survey (ZipExport)

// The name of the export, used by the email client to name the attachment
- (NSString *)getExportFileName;

// returns a zip data stream of the survey document; used by the email client for the attachment
- (NSData *)exportToNSDataError:(NSError **)error;

// Creates an importable survey (zip file) in the Documents directory (for file sharing with iTunes)
// Returns YES if successful, or NO if it fails
// The new file will have name {survey.title}.poz
// use force to overwrite an existing file with the same name.
- (BOOL)exportToDiskWithForce:(BOOL)force error:(NSError **)error;

@end

