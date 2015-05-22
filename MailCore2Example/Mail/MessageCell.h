//
//  MessageCell.h
//  ThatInbox
//
//  Created by Andrey Yastrebov on 20.09.13.
//  Copyright (c) 2013 com.inkmobility. All rights reserved.
//
#import "MailInfo.h"
#import "ApplicationDirector.h"
#import <UIKit/UIKit.h>
#import <MailCore/MailCore.h>

@interface MessageCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *addressTextField;
@property (weak, nonatomic) IBOutlet UILabel *subjectTextField;
@property (weak, nonatomic) IBOutlet UILabel *detailTextField;
@property (weak, nonatomic) IBOutlet UILabel *dateTimeField;
@property (weak, nonatomic) IBOutlet UIImageView *attachementIcon;
@property (weak, nonatomic) IBOutlet UIImageView *flagIcon;
@property (weak, nonatomic) IBOutlet UIImageView *unseenIcon;
@property (weak, nonatomic) IBOutlet UIImageView *forwardAnswered;

@property (strong, nonatomic) MailFolderInfo *folder;
@property (strong, nonatomic) MCOAbstractMessage *message;

@property (nonatomic, strong) MCOIMAPMessageRenderingOperation * messageRenderingOperation;

@end
