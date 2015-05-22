//
//  MCOPOPMessage.m
//  CECiTurbo
//
//  Created by DongXing on 4/17/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "MCOPOPMessage.h"

@implementation MCOPOPMessage

@synthesize header;

-(MCOMessageHeader *)header{
    if (_parser) {
        return _parser.header;
    }else{
        return header;
    }
}


-(NSString *)plainTextBodyRendering{
    return [_parser plainTextBodyRendering];
}

-(NSString *)plainTextBodyRenderingAndStripWhitespace:(BOOL)stripWhitespace{
    return [_parser plainTextBodyRenderingAndStripWhitespace:stripWhitespace];
}

-(NSString *)plainTextRendering{
    return [_parser plainTextRendering];
}

-(NSString *)htmlBodyRendering{
    return [_parser htmlBodyRendering];
}

-(NSString *)htmlRenderingWithDelegate:(id<MCOHTMLRendererDelegate>)delegate{
    return [_parser htmlRenderingWithDelegate:delegate];
}

-(MCOAbstractPart *)partForContentID:(NSString *)contentID{
    return [_parser partForContentID:contentID];
}

-(MCOAbstractPart *)partForUniqueID:(NSString *)uniqueID{
    return [_parser partForUniqueID:uniqueID];
}

-(NSArray *)attachments{
    return [_parser attachments];
}

-(NSArray *)htmlInlineAttachments{
    return [_parser htmlInlineAttachments];
}

-(NSArray *)requiredPartsForRendering{
    return [_parser requiredPartsForRendering];
}

-(void)messageData:(NSData *)messageData{
    _parser = [MCOMessageParser messageParserWithData:messageData];
}

- (void)encodeWithCoder:(NSCoder *)encoder{
    [encoder encodeBool:self.fetched forKey:@"fetched"];
    [encoder encodeInteger:self.flags forKey:@"flags"];
    [encoder encodeObject:self.uid forKey:@"uid"];
    if (_parser) {
        [encoder encodeObject:_parser.data forKey:@"data"];
    }else{
        [encoder encodeObject:self.header forKey:@"header"];
    }
}

- (id)initWithCoder:(NSCoder *)decoder{
    
    MCOPOPMessage *message = [[MCOPOPMessage alloc] init];
    NSData *data = [decoder decodeObjectForKey:@"data"];
    if (data) {
        [message messageData:data];
    }else{
        message.header = [decoder decodeObjectForKey:@"header"];
    }
    
    message.fetched = [decoder decodeBoolForKey:@"fetched"];
    message.flags = [decoder decodeIntegerForKey:@"flags"];
    message.uid = [decoder decodeObjectForKey:@"uid"];
    message.index = 0;
    return message;
}

@end
