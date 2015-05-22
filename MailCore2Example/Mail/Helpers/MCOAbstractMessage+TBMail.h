//
//  MCOAbstractMessage+TBMail.h
//  CECiTurbo
//
//  Created by DongXing on 4/20/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import <MailCore.h>
#import "MCOPOPMessage.h"

@interface MCOAbstractMessage (TBMail)

-(BOOL)updateFlags:(MCOMessageFlag)flags;
-(MCOMessageFlag)TBFlags;

-(BOOL)isEqual:(id)object;

-(NSUInteger)hash;

@end
