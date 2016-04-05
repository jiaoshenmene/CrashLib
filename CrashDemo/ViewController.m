//
//  ViewController.m
//  CrashDemo
//
//  Created by 杜甲 on 16/4/5.
//  Copyright © 2016年 杜甲. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    [self performSelector:@selector(fakeCrash)];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"JSPatchTest" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    btn.frame = CGRectMake(10, 10, 100, 50);
    [self.view addSubview:btn];
    [btn addTarget:self action:@selector(jspatchMethod) forControlEvents:UIControlEventTouchUpInside];
    

}

//- (void)jspatchMethod
//{
//    NSLog(@"oc method");
//}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    NSLog(@"resolveInstanceMethod");
    return NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
