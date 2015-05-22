//
//  MessageDetailViewController.h
//  ThatInbox
//
//  Created by Liyan David Chang on 7/9/13.
//  Copyright (c) 2013 Ink. All rights reserved.
//

#import "MCTMsgViewController.h"

@protocol MessageActionDelegate <NSObject>
@required
-(void)flagsMessage:(MCOAbstractMessage*)message;
-(void)trashMessage:(MCOAbstractMessage*)message;
-(void)organizeMessage:(MCOAbstractMessage*)message;
@end

@interface MessageDetailViewController : MCTMsgViewController

@property (nonatomic, assign) id<MessageActionDelegate> delegate;

@end
