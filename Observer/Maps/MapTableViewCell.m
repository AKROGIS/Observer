//
//  MapTableViewCell.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "MapTableViewCell.h"
#import "AKRDownloadView.h"

@interface MapTableViewCell ()
@property (weak, nonatomic) IBOutlet AKRDownloadView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIImageView *startDownloadImageView;
@end

@implementation MapTableViewCell

- (void)setPercentComplete:(float)percentComplete
{
    self.downloadProgressView.percentComplete = percentComplete;
}

- (void)setDownloading:(BOOL)downloading
{
    if (downloading != _downloading) {
        _downloading = downloading;
        self.downloadProgressView.hidden = !downloading;
        self.startDownloadImageView.hidden = downloading;
        self.downloadProgressView.downloading = downloading;
    }
}

@end
