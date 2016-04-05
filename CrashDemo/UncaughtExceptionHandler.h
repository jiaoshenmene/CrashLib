//
//  UncaughtExceptionHandler.h
//  CrashDemo
//
//  Created by 杜甲 on 16/4/5.
//  Copyright © 2016年 杜甲. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UncaughtExceptionHandler : NSObject
{
    BOOL dismissed;
}

@end
void HandleException(NSException *exception);
void SignalHandler(int signal);


void InstallUncaughtExceptionHandler(void);

