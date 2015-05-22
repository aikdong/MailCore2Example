//
//  XJAlertManager.m
//  XJAlertManagerDemo
//
//  Created by jimi on 2014/11/21.
//  Copyright (c) 2014年 XJIMI. All rights reserved.
//

#import "XJAlertManager.h"

@interface XJAlertManager ()

@property (nonatomic, strong) id alert;
@property (nonatomic, weak) id viewController;

@end

@implementation XJAlertManager

+ (instancetype)actionSheetWithTitle:(NSString *)title message:(NSString *)message viewController:(UIViewController *)viewController
{
    return [XJAlertManager initWithTitle:title message:message style:XJAlertStyleActionSheet viewController:viewController];
}

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message viewController:(UIViewController *)viewController
{
    return [XJAlertManager initWithTitle:title message:message style:XJAlertStyleAlert viewController:viewController];
}

+ (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
                        style:(XJAlertStyle)style
               viewController:(UIViewController *)viewController
{
    XJAlertManager *alertManager = [[XJAlertManager alloc] init];
    if ([UIAlertController class])
    {
        UIAlertControllerStyle alertStyle = (NSInteger)style;
        alertManager.alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:alertStyle];
        alertManager.viewController = viewController;
    }
    else
    {
        if (style == XJAlertStyleAlert)
        {
            alertManager.alert = [UIAlertView bk_alertViewWithTitle:title message:message];
        }
        else if (style == XJAlertStyleActionSheet)
        {
            alertManager.alert = [UIActionSheet bk_actionSheetWithTitle:title];
            alertManager.viewController = viewController;
        }
    }
    return alertManager;
}

- (void)addButtonWithTitle:(NSString *)title handler:(void (^)(void))block
{
    [self addButtonWithTitle:title style:XJAlertActionStyleDefault handler:block];
}

- (void)addDestructiveButtonWithTitle:(NSString *)title handler:(void (^)(void))block
{
    [self addButtonWithTitle:title style:XJAlertActionStyleDestructive handler:block];
}

- (void)addCancelButtonWithTitle:(NSString *)title handler:(void (^)(void))block
{
    [self addButtonWithTitle:title style:XJAlertActionStyleCancel handler:block];
}

- (void)addButtonWithTitle:(NSString *)title style:(XJAlertActionStyle)style handler:(void (^)(void))block
{
    if ([UIAlertController class])
    {
        UIAlertActionStyle actionStyle = (NSInteger)style;
        UIAlertAction *action = [UIAlertAction actionWithTitle:title style:actionStyle handler:^(UIAlertAction *action) {
            [self handlerBlock:block];
        }];
        [self.alert addAction:action];
    }
    else
    {
        if (style == XJAlertActionStyleCancel)
        {
            [self.alert bk_setCancelButtonWithTitle:title handler:^{
                [self handlerBlock:block];
            }];
            return;
        }
        else if (style == XJAlertActionStyleDestructive)
        {
            if ([self.alert isKindOfClass:[UIActionSheet class]])
            {
                [self.alert bk_setDestructiveButtonWithTitle:title handler:^{
                    [self handlerBlock:block];
                }];
                return;
            }
        }
        
        [self.alert bk_addButtonWithTitle:title handler:^{
            [self handlerBlock:block];
        }];
    }
}

- (void)handlerBlock:(void (^)(void))block
{
    if (block) block();
    self.alert = nil;
    self.viewController = nil;
}

- (void)show
{
    if ([UIAlertController class])
    {
        // 由于某种原因，presentViewController里的内容并不会真的马上触发执行，除非有一个主线程事件触发这种消费。比如在弹出慢的时候，你随便点击一下屏幕，马上就能弹出来。
        // 放到主程序執行
//        dispatch_async(dispatch_get_main_queue(), ^{
            [self.viewController presentViewController: self.alert animated: true completion: nil];
//        });
    }
    else
    {
        if ([self.alert isKindOfClass:[UIAlertView class]])
        {
            [self.alert show];
        }
        else if ([self.alert isKindOfClass:[UIActionSheet class]])
        {
            UIViewController *viewController = self.viewController;
            [self.alert showInView:viewController.view];
        }
    }
}

@end
