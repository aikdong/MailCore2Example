//
//  MCOAbstractMessage+TBMail.m
//  CECiTurbo
//
//  Created by DongXing on 4/20/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "MCOAbstractMessage+TBMail.h"

@implementation MCOAbstractMessage (TBMail)

-(MCOMessageFlag)TBFlags{
    if ([self isMemberOfClass:[MCOIMAPMessage class]]) {
        return [(MCOIMAPMessage*)self flags];
    }else if([self isMemberOfClass:[MCOPOPMessage class]]){
        return [(MCOPOPMessage*)self flags];
    }
    return MCOMessageFlagNone;
}

-(BOOL)updateFlags:(MCOMessageFlag)flags{
    
    if ([self isMemberOfClass:[MCOIMAPMessage class]]) {
        MCOIMAPMessage *msg = (MCOIMAPMessage*)self;
        if (msg.flags&flags || msg.flags==flags)
            return NO;
        else
            msg.flags = msg.flags|flags;
    }else if([self isMemberOfClass:[MCOPOPMessage class]]){
        MCOPOPMessage *msg = (MCOPOPMessage*)self;
        if (msg.flags&flags || msg.flags==flags)
            return NO;
        else
            msg.flags = msg.flags|flags;
    }
    
    return YES;
}

-(BOOL)isEqual:(id)object{
    if ([self hash] == [object hash]) {
        return YES;
    }
    return NO;
}

-(NSUInteger)hash{
    if ([self isMemberOfClass:[MCOIMAPMessage class]]) {
        return [(MCOIMAPMessage*)self uid];
    }else if([self isMemberOfClass:[MCOPOPMessage class]]){
        return [[(MCOPOPMessage*)self uid] hash];
    }
    return [self hash];
}

@end
