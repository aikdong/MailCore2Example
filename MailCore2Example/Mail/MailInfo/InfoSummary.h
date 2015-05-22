//
//  InfoSummary.h
//  CECiTurbo
//
//  Created by DongXing on 2/5/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "InfoSummary.h"
#import <SDWebImage/UIImageView+WebCache.h>

@protocol InfoSummary
@required
-(NSString*) summaryTitle;

@optional
-(NSString*) summaryDetailTitle;
-(NSInteger) summaryBadage;
-(void) summaryImageToCellImageView:(UIImageView*)imageView completed:(SDWebImageCompletionBlock)completed;

@end