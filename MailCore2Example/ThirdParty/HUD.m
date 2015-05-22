//
//  HUD.m
//  BeatGuide
//
// This code is distributed under the terms and conditions of the MIT license.
//
// Copyright (c) 2011 Marin Todorov
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

#import "HUD.h"
#import "QuartzCore/QuartzCore.h"
#import "XJAlertManager.h"

@interface GlowButton : UIButton <MBProgressHUDDelegate>
@end

@implementation GlowButton
{
    NSTimer* timer;
    float glowDelta;
}

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        //effect
        self.layer.shadowColor = [UIColor whiteColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(1,1);
        self.layer.shadowOpacity = 0.9;
        
        glowDelta = 0.2;
        timer = [NSTimer timerWithTimeInterval:0.05
                                        target:self
                                      selector:@selector(glow)
                                      userInfo:nil
                                       repeats:YES];
        
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    }
    return self;
}

-(void)glow
{
    if (self.layer.shadowRadius>7.0 || self.layer.shadowRadius<0.1) {
        glowDelta *= -1;
    }
    self.layer.shadowRadius += glowDelta;
}

-(void)dealloc
{
    [timer invalidate];
    timer = nil;
}

@end


static UIView* lastViewWithHUD;

@implementation HUD

+(UIView*)rootView
{
    return [self rootViewController].view;
}

+(UIViewController *)rootViewController{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

+(MBProgressHUD*)showUIBlockingIndicatorWithText:(NSString*)str view:(UIView*)view
{
    [HUD hideUIBlockingIndicator];
    
    //show the HUD
    if (!view) view = [self rootView];
    if (!view) return nil;
    lastViewWithHUD = view;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
    
    if (str!=nil) {
        hud.labelText = str;
    } else {
        hud.labelText = @"Loading...";
    }
    
    return hud;
}

+(MBProgressHUD*)showUIBlockingIndicatorWithText:(NSString*)str withTimeout:(NSTimeInterval)time view:(UIView*)view
{
    MBProgressHUD* hud = [self showUIBlockingIndicatorWithText:str view:view];
    hud.customView = [[UIView alloc] initWithFrame:CGRectMake(0,0,37,37)];
    hud.mode = MBProgressHUDModeText;
    if (time > 0) {
        [hud hide:YES afterDelay:time];
    }
    
    return hud;
}

+(void)showErrorWithTitle:(NSString*)titleText text:(NSString*)text viewController:(UIViewController*)viewController handler:(void (^)(void))block{
    
    if (!viewController) {
        viewController = [self rootViewController];
    }
    
    XJAlertManager *alert = [XJAlertManager alertWithTitle:titleText
                                                   message:text
                                            viewController:viewController];
    
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil) handler:block];

    [alert show];
}

+(MBProgressHUD*)showErrorWithTitle:(NSString*)titleText text:(NSString*)text target:(id)t action:(SEL)sel view:(UIView*)view
{

    return [self showAlertWithTitle:titleText text:text target:t action:sel image:[UIImage imageNamed:@"HUDError"] withTimeout:0 view:view];
}

+(MBProgressHUD*)showErrorWithTitle:(NSString*)titleText text:(NSString*)text view:(UIView*)view
{
    return [self showAlertWithTitle:titleText text:text target:nil action:NULL image:[UIImage imageNamed:@"HUDError"] withTimeout:0 view:view];
}

+(MBProgressHUD*)showTextWithTitle:(NSString*)titleText text:(NSString*)text withTimeout:(NSTimeInterval)time view:(UIView*)view
{
    MBProgressHUD *hud = [self showAlertWithTitle:titleText text:text target:nil action:NULL image:nil withTimeout:time view:view];

    return hud;
}

+(MBProgressHUD*)showSuccessWithTitle:(NSString*)titleText text:(NSString*)text withTimeout:(NSTimeInterval)time view:(UIView*)view{
    MBProgressHUD *hud = [self showAlertWithTitle:titleText text:text target:nil action:NULL image:[UIImage imageNamed:@"HUDSuccess"] withTimeout:time view:view];

    return hud;
}

+(MBProgressHUD*)showAlertWithTitle:(NSString*)titleText text:(NSString*)text target:(id)t action:(SEL)sel image:(UIImage*)image withTimeout:(NSTimeInterval)time view:(UIView*)view
{
    [HUD hideUIBlockingIndicator];
    
    //show the HUD
    if (!view) view = [self rootView];
    if (!view) return nil;
    lastViewWithHUD = view;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
    
    //set the text
    hud.labelText = titleText;
    hud.detailsLabelText = text;
    
    //set the close button
    GlowButton* btnClose = [GlowButton buttonWithType:UIButtonTypeCustom];
    if (t && sel!=NULL) {
        [btnClose addTarget:t action:sel forControlEvents:UIControlEventTouchUpInside];
    } else {
        [btnClose addTarget:self action:@selector(hideUIBlockingIndicator) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [btnClose setImage:image forState:UIControlStateNormal];
    [btnClose setFrame:CGRectMake(0,0,image.size.width,image.size.height)];
    
    //hud settings
    hud.customView = btnClose;
    hud.mode = MBProgressHUDModeCustomView;
    
    if (time > 0) {
        [hud hide:YES afterDelay:time];
    }
    
    return hud;
}

+(void)hideUIBlockingIndicator
{
    [MBProgressHUD hideHUDForView:lastViewWithHUD animated:YES];
}


+(MBProgressHUD*)showUIBlockingProgressIndicatorWithText:(NSString*)str andProgress:(float)progress view:(UIView*)view
{
    [HUD hideUIBlockingIndicator];
    
    //show the HUD
    if (!view) view = [self rootView];
    if (!view) return nil;
    lastViewWithHUD = view;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
    
    //set the text
    hud.labelText = str;
    hud.mode = MBProgressHUDModeDeterminate;
    hud.progress = progress;
    
    return hud;
}

@end