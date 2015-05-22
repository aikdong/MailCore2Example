//
//  MailListViewController.h
//  CECiTurbo
//
//  Created by DongXing on 3/26/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import <MailCore.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import "MailInfo.h"
#import "MessageDetailViewController.h"

@interface MailListViewController : UITableViewController

@property (nonatomic,strong) SmartFolder * smartFolder;

@end
