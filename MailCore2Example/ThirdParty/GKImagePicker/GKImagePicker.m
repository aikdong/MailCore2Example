//
//  GKImagePicker.m
//  GKImagePicker
//
//  Created by Georg Kitz on 6/1/12.
//  Copyright (c) 2012 Aurora Apps. All rights reserved.
//

#import "GKImagePicker.h"
#import "GKImageCropViewController.h"
#import "UIImage+Custom.h"

@interface GKImagePicker ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate, GKImageCropControllerDelegate>
@property (nonatomic, strong, readwrite) UIImagePickerController *imagePickerController;
- (void)_hideController;
@end

@implementation GKImagePicker

#pragma mark Getter/Setter

@synthesize cropSize, maxSize, delegate, resizeableCropArea;
@synthesize imagePickerController = _imagePickerController;

#pragma mark Init Methods

- (id)init{
    if (self = [super init]) {
        self.title = @"";
        self.cropSize = CGSizeMake(320, 320);
        self.maxSize = CGSizeMake(1024.0, 1024.0);
        self.resizeableCropArea = NO;
        _imagePickerController = [[UIImagePickerController alloc] init];
        _imagePickerController.delegate = self;
    }
    return self;
}

# pragma mark Private Methods

- (void)_hideController{
    
    if (![_imagePickerController.presentedViewController isKindOfClass:[UIPopoverController class]]){
        [self.imagePickerController dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark UIImagePickerDelegate Methods

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    
    if ([self.delegate respondsToSelector:@selector(imagePickerDidCancel:)]) {
      
        [self.delegate imagePickerDidCancel:self];
        
    } else {
        
        [self _hideController];
    
    }
    
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{

    GKImageCropViewController *cropController = [[GKImageCropViewController alloc] init];
    cropController.preferredContentSize = picker.preferredContentSize;
    
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    cropController.sourceImage = [image resizableImageWithMaxSize:self.maxSize];
    
    cropController.resizeableCropArea = self.resizeableCropArea;
    cropController.cropSize = self.cropSize;
    cropController.delegate = self;
    cropController.title = self.title;
    cropController.sourceType = self.imagePickerController.sourceType;
    
    [picker pushViewController:cropController animated:YES];
}

#pragma mark GKImagePickerDelegate

- (void)imageCropController:(GKImageCropViewController *)imageCropController didFinishWithCroppedImage:(UIImage *)croppedImage{
    
    if ([self.delegate respondsToSelector:@selector(imagePicker:pickedImage:)]) {
        [self.delegate imagePicker:self pickedImage:croppedImage];   
    }
}

-(void)imageCropControllerDidCancel:(GKImageCropViewController *)imageCropController{
    if ([self.delegate respondsToSelector:@selector(imagePickerDidCancel:)]) {
        
        [self.delegate imagePickerDidCancel:self];
        
    } else {
        
        [self _hideController];
        
    }
}

@end
