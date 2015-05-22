//
//  MailViewController.h
//  CECiTurbo
//
//  Created by DongXing on 3/26/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "MailFolderViewController.h"
#import "EmailAccountViewController.h"
#import "AttachmentListViewController.h"
#import "ApplicationDirector.h"

@interface MailMainViewController : UITableViewController

@property (nonatomic,strong) NSArray *smartFolders;
@property (nonatomic,strong) NSArray *internalAccounts;
@property (nonatomic,strong) NSMutableArray *mailAccounts;


@end
