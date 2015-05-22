//
//  UIImage+ImageWithColor.h
//  UIImage-ImageWithColor
//
//  Created by Bruno Tortato Furtado on 14/12/13.
//  Copyright (c) 2013 No Zebra Network. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <UIKit/UIKit.h>

@interface UIImage (Custom)

#pragma mark - Image with color
+ (UIImage *)imageWithColor:(UIColor *)color;

+ (UIImage *)imageWithColor:(UIColor *)color withSize:(CGSize)size;

#pragma mark - Screen shot
+ (UIImage *)screenshot;

#pragma mark - Tint color
+ (UIImage *)imageNamed:(NSString *)name fromWhiteToColor:(UIColor *)color;
- (UIImage *)imageTintedWithColorFromeWhite:(UIColor *)color;

+ (UIImage *)imageNamed:(NSString *)name fromBlackToColor:(UIColor *)color;
- (UIImage *)imageTintedWithColorFromeBlack:(UIColor *)color;
- (UIImage *)imageTintedWithColorFromeBlack:(UIColor *)color fraction:(CGFloat)fraction;

#pragma mark - Trim
- (UIImage *) trimToSquare;

#pragma mark - Orientation
- (UIImage *) fixOrientation;

- (UIImage *)crop:(CGRect)rect;

- (UIImage *)resizableImageWithMaxSize:(CGSize)size;

- (void) showsImage;

+ (UIImage *)takeScrollViewImage:(UIScrollView*)view;

@end