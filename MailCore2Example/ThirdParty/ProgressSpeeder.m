//
//  ProcessSpeeder.m
//  CECiTurbo
//
//  Created by DongXing on 3/20/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "ProgressSpeeder.h"

@interface ProgressSpeeder()
{
    NSDate *date;
    long long currentBytes;
    long long maximum;
    long long speed;
}
@end

@implementation ProgressSpeeder
-(instancetype)init{
    if ( (self = [super init]) ) {
        speed = maximum = currentBytes = 0;
    }
    return self;
}

-(void)addBytes:(NSUInteger)count{
    
    currentBytes += count;
    
    //时间差
    NSDate *now = [NSDate date];
    if (!date)
        date = now;
    else
    {
        double interval = [now timeIntervalSinceDate:date];
        speed = (currentBytes/interval);
    }
}

-(NSInteger)currentBytes:(long long)new maximumBytes:(long long)max{
    [self addBytes:(NSInteger)(new-currentBytes)];
    maximum = max;
    
    if (maximum > 0) {
        NSInteger progress = (NSInteger)(100 * new / maximum);
        if (progress < 0) {
            return 0;
        }else if (progress > 100){
            return 100;
        }else{
            return progress;
        }
    }else{
        return 0;
    }
    
}

-(NSString*)formatedSpeed{
    return [NSByteCountFormatter stringFromByteCount:speed countStyle:NSByteCountFormatterCountStyleFile];
}

@end
