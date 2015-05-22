//
//  AddAddressViewController.h
//  CECiTurbo
//
//  Created by DongXing on 5/5/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import <MailCore.h>
#import <UIKit/UIKit.h>
#import "ApplicationDirector.h"

@protocol AddAddressCompleteDelegate <NSObject>

@optional
-(void)addAddressComplete:(UITextField*)bindTextField with:(MCOAddress*)info;

@end

@interface AddAddressViewController : UITableViewController

@property (nonatomic,weak) UITextField *bindTextField;
@property (nonatomic,strong) id<AddAddressCompleteDelegate> delegate;

@end
