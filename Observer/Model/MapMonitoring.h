//
//  MapMonitoring.h
//  Observer
//
//  Created by Regan Sarwas on 2013-07-06.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BaseMap;
@class BaseMapManager;

@protocol MapMonitoring <NSObject>

@optional

- (void)mapDidFinishLoad:(BaseMap *)map;
- (void)map:(BaseMap *)map didFailLoadWithError:(NSError *)error;

- (void)mapDidFinishDownload:(BaseMap *)map;
- (void)map:(BaseMap *)map didFailDownloadWithError:(NSError *)error;

- (void)mapsDidFinishServerRequest:(BaseMapManager *)maps;
- (void)mapsDidFinishAllServerRequests:(BaseMapManager *)maps;
- (void)maps:(BaseMapManager *)maps didFailServerRequestWithError:(NSError *)error;

@end
