//
//  ProcessSpeeder.h
//  CECiTurbo
//
//  Created by DongXing on 3/20/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ProgressSpeeder : NSObject

// You can only set bytes.
-(void)addBytes:(NSUInteger)count;

-(NSInteger)currentBytes:(long long)newBytes maximumBytes:(long long)max;

-(NSString*)formatedSpeed;

@end
