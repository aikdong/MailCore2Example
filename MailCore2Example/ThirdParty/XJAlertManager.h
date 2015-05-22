//
//  XJAlertManager.h
//  XJAlertManagerDemo
//
//  Created by jimi on 2014/11/21.
//  Copyright (c) 2014年 XJIMI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIAlertView+BlocksKit.h"
#import "UIActionSheet+BlocksKit.h"

typedef NS_ENUM(NSInteger, XJAlertStyle) {
    XJAlertStyleActionSheet = 0,
    XJAlertStyleAlert,
};

typedef NS_ENUM(NSInteger, XJAlertActionStyle) {
    XJAlertActionStyleDefault = 0,
    XJAlertActionStyleCancel,
    XJAlertActionStyleDestructive
};

@interface XJAlertManager : NSObject

+ (instancetype)actionSheetWithTitle:(NSString *)title message:(NSString *)message viewController:(UIViewController *)viewController;

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message viewController:(UIViewController *)viewController;

- (void)addButtonWithTitle:(NSString *)title handler:(void (^)(void))block;

- (void)addDestructiveButtonWithTitle:(NSString *)title handler:(void (^)(void))block;

- (void)addCancelButtonWithTitle:(NSString *)title handler:(void (^)(void))block;

- (void)show;

@end
