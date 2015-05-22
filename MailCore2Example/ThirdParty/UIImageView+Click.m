//
//  ClickImage.m
//  TableView
//
//  Created by LYZ on 14-1-13.
//  Copyright (c) 2014年 LYZ. All rights reserved.
//

#import "UIImageView+Click.h"
#import "JTSImageViewController.h"
#import "JTSImageInfo.h"
#import "HUD.h"
#import "objc/runtime.h"
#import <SDWebImageDownloader.h>

@implementation UIImageView (Click)

static char clickImageURLKey;

- (void)setClickObject:(id)object {
    if (object) {
        if (![object isMemberOfClass:[UIImage class]]) {
            objc_setAssociatedObject(self, &clickImageURLKey, object, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(imageTapped:)];
        [tap setNumberOfTapsRequired:1];
        [self addGestureRecognizer:tap];
        self.userInteractionEnabled = YES;
        
    }else{
        
        objc_setAssociatedObject(self, &clickImageURLKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.userInteractionEnabled = NO;
    }
}

- (id)imageObject {

    return objc_getAssociatedObject(self, &clickImageURLKey);
}

- (void)imageTapped:(id __unused)sender {
    // Create image info
    JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
    
    if (self.imageObject){
        imageInfo.imageURL = (NSURL *)self.imageObject;
    } else {
        imageInfo.image = self.image;
    }
    imageInfo.referenceRect = self.frame;
    imageInfo.referenceView = self.superview;
    imageInfo.referenceContentMode = UIViewContentModeScaleAspectFit;
    imageInfo.referenceCornerRadius = self.layer.cornerRadius;
    // Setup view controller
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
    // Present the view controller.
    [imageViewer showFromViewController:[HUD rootViewController] transition:JTSImageViewControllerTransition_FromOriginalPosition];
}
@end

