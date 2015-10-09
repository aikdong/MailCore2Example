//
//  BaseFormViewController.h
//  CECiTurbo
//
//  Created by DongXing on 1/22/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import <XLForm.h>
#import "JSONModel.h"
#import "XJAlertManager.h"
#import "HUD.h"
#import "NSDate+DateTools.h"

typedef void (^ProcessCompleteBlock)(id object,BOOL isLocal, NSError* err);

@protocol FormDidProcessCompleteDelegate <NSObject>

@optional
-(void)formDidProcessComplete:(id)object with:(BOOL)success;

-(void)newSelfComplete:(UIViewController*)oldController with:(UIViewController*)newController;

@end

@interface BaseFormViewController : XLFormViewController

@property (nonatomic,strong) id<FormDidProcessCompleteDelegate> delegate;


- (instancetype)initWithObject:(id)object;
- (instancetype)initWithObject:(id)object style:(UITableViewStyle)style;


- (XLFormDescriptor *)configureForm:(id)object;

/**
 *  驗證邏輯錯誤
 */
- (NSError*)formLogicalError;
- (BOOL)saveWithValues:(NSDictionary *)dict completion:(ProcessCompleteBlock)completion;

@end