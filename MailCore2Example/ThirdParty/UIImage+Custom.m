//
//  UIImage+ImageWithColor.m
//  UIImage-ImageWithColor
//
//  Created by Bruno Tortato Furtado on 14/12/13.
//  Copyright (c) 2013 No Zebra Network. All rights reserved.
//

#import "UIImage+Custom.h"
#import "JTSImageViewController.h"
#import "JTSImageInfo.h"
#import "HUD.h"

@implementation UIImage (Custom)

+ (UIImage *)imageWithColor:(UIColor *)color
{
    return [self imageWithColor:color withSize:CGSizeMake(1, 1)];
}

+ (UIImage *)imageWithColor:(UIColor *)color withSize:(CGSize)size
{
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}


#pragma mark - Screen shot
+ (UIImage *)screenshot
{
    UIScreen *screen = [UIScreen mainScreen] ;
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    UIGraphicsBeginImageContextWithOptions(screen.bounds.size, NO, 0);
    [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

#pragma mark - Tint color

+ (UIImage *)imageNamed:(NSString *)name fromWhiteToColor:(UIColor *)color{
    // load the image
    UIImage *img = [UIImage imageNamed:name];
    
    img = [img imageTintedWithColorFromeWhite:color];
    
    //return the color-burned image
    return img;
}

- (UIImage *)imageTintedWithColorFromeWhite:(UIColor *)color{
    if (color) {
        // begin a new image context, to draw our colored image onto
        UIGraphicsBeginImageContext(self.size);
        
        // get a reference to that context we created
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        // set the fill color
        [color setFill];
        
        // translate/flip the graphics context (for transforming from CG* coords to UI* coords
        CGContextTranslateCTM(context, 0, self.size.height);
        CGContextScaleCTM(context, 1.0, -1.0);
        
        // set the blend mode to color burn, and the original image
        CGContextSetBlendMode(context, kCGBlendModeColorBurn);
        CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
        CGContextDrawImage(context, rect, self.CGImage);
        
        // set a mask that matches the shape of the image, then draw (color burn) a colored rectangle
        CGContextClipToMask(context, rect, self.CGImage);
        CGContextAddRect(context, rect);
        CGContextDrawPath(context,kCGPathFill);
        
        // generate a new UIImage from the graphics context we drew onto
        UIImage *coloredImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return coloredImg;
    }
    return self;
}

+ (UIImage *)imageNamed:(NSString *)name fromBlackToColor:(UIColor *)color{
    // load the image
    UIImage *img = [UIImage imageNamed:name];
    
    if (color) {
        return [img imageTintedWithColorFromeBlack:color];
    }
    
    return img;
}

- (UIImage *)imageTintedWithColorFromeBlack:(UIColor *)color
{
    // This method is designed for use with template images, i.e. solid-coloured mask-like images.
    return [self imageTintedWithColorFromeBlack:color fraction:0.0]; // default to a fully tinted mask of the image.
}


- (UIImage *)imageTintedWithColorFromeBlack:(UIColor *)color fraction:(CGFloat)fraction
{
    if (color) {
        // Construct new image the same size as this one.
        UIImage *image;
        UIGraphicsBeginImageContextWithOptions([self size], NO, 0);
        CGRect rect = CGRectZero;
        rect.size = [self size];
        
        // Composite tint color at its own opacity.
        [color set];
        UIRectFill(rect);
        
        // Mask tint color-swatch to this image's opaque mask.
        // We want behaviour like NSCompositeDestinationIn on Mac OS X.
        [self drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0];
        
        // Finally, composite this image over the tinted mask at desired opacity.
        if (fraction > 0.0) {
            // We want behaviour like NSCompositeSourceOver on Mac OS X.
            [self drawInRect:rect blendMode:kCGBlendModeSourceAtop alpha:fraction];
        }
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return image;
    }
    
    return self;
}

#pragma mark - Trim
- (UIImage*) trimToSquare{
    
    CGFloat minSize = MIN(self.size.width, self.size.height);
    
    CGPoint offset = CGPointMake((self.size.width-minSize)/2, (self.size.height-minSize)/2);
    
    CGRect clippedRect  = CGRectMake(offset.x, offset.y, minSize, minSize);
    CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], clippedRect);
    
    UIImage* image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return image;
}

#pragma mark - Orientation
- (UIImage *)fixOrientation {
    
    // No-op if the orientation is already correct
    if (self.imageOrientation == UIImageOrientationUp) return self;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (self.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, self.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, self.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (self.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, self.size.width, self.size.height,
                                             CGImageGetBitsPerComponent(self.CGImage), 0,
                                             CGImageGetColorSpace(self.CGImage),
                                             CGImageGetBitmapInfo(self.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (self.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,self.size.height,self.size.width), self.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,self.size.width,self.size.height), self.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

- (UIImage *)crop:(CGRect)rect {
    CGFloat scale = UIScreen.mainScreen.scale;
    if (scale > 1.0f) {
        rect = CGRectMake(rect.origin.x * scale,
                          rect.origin.y * scale,
                          rect.size.width * scale,
                          rect.size.height * scale);
    }
    
    CGImageRef imageRef = CGImageCreateWithImageInRect(self.CGImage, rect);
    UIImage *result = [UIImage imageWithCGImage:imageRef scale:scale orientation:self.imageOrientation];
    CGImageRelease(imageRef);
    return result;
}

- (UIImage *) scaleToSize: (CGSize)size
{
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)resizableImageWithMaxSize:(CGSize)size;
{
    float widthRatio = size.width/self.size.width;
    float heightRatio = size.height/self.size.height;
    
    if(widthRatio > heightRatio)
    {
        size=CGSizeMake(self.size.width*heightRatio,self.size.height*heightRatio);
    } else {
        size=CGSizeMake(self.size.width*widthRatio,self.size.height*widthRatio);
    }
    
    return [self scaleToSize:size];
}

-(void)showsImage{
    // Create image info
    JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
    imageInfo.image = self;
    // Setup view controller
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundOption_Blurred];
    // Present the view controller.
    [imageViewer showFromViewController:[HUD rootViewController] transition:JTSImageViewControllerTransition_FromOriginalPosition];
}

+(UIImage *)takeScrollViewImage:(UIScrollView *)view{
    if (!view)
        return nil;
    
    CGPoint savedContentOffset = view.contentOffset;
    CGRect savedFrame = view.frame;
    view.contentOffset = CGPointZero;
    view.frame = CGRectMake(0, 0, view.contentSize.width, view.contentSize.height);
    
    UIGraphicsBeginImageContextWithOptions(view.contentSize,NO,0);
    
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    view.contentOffset = savedContentOffset;
    view.frame = savedFrame;
    UIGraphicsEndImageContext();
    
    return image;
}

@end