//
//  MCOPOPMessage.h
//  CECiTurbo
//
//  Created by DongXing on 4/17/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import <MailCore.h>
#import "MCOMessageParser.h"

@interface MCOPOPMessage : MCOMessageBuilder <NSCoding>{
    MCOMessageParser *_parser;
}

@property (nonatomic, assign) uint32_t index;
@property (nonatomic, strong) NSString *uid;

@property (nonatomic, assign) BOOL fetched;

/** Flags of the message, like if it is deleted, read, starred etc */
@property (nonatomic, assign) MCOMessageFlag flags;

-(void)messageData:(NSData*)messageData;

@end
