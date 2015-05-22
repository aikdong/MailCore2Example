//
//  ClickImage.h
//  TableView
//
//  Created by LYZ on 14-1-13.
//  Copyright (c) 2014年 LYZ. All rights reserved.
//

#import <UIKit/UIKit.h>

//代理型，只提供简单功能
@interface UIImageView (Click)

/**
 * Get the current image URL.
 *
 * Note that because of the limitations of categories this property can get out of sync
 * if you use sd_setImage: directly.
 */
- (id)imageObject;

/**
 * Set the imageView `image` with an `url` or image.
 *
 *
 * @param url The url for the image or an `url`.
 */
- (void)setClickObject:(id)object;

- (void)imageTapped:(id __unused)sender;

@end