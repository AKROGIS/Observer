//
//  Observation+CsvExport.h
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Observation.h"
#import "ProtocolFeature.h"

@interface Observation (CsvExport)

+(NSString *)csvHeaderForFeature:(ProtocolFeature *)feature;
-(NSString *)asCsvForFeature:(ProtocolFeature *)feature;

@end
