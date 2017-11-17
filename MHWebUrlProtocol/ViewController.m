//
//  ViewController.m
//  MHWebUrlProtocol
//
//  Created by 马浩 on 2017/11/17.
//  Copyright © 2017年 HuZhang. All rights reserved.
//

#import "ViewController.h"
#import "MHURLProtocol.h"
@interface ViewController ()
{
    UIWebView * _web;
    UIButton * _openNoImageBtn;//开启/关闭无图
    UIButton * _webBack;//web返回
    UIButton * _webForward;//web前进
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //不会用 stroyboard 好low
    self.view.backgroundColor = [UIColor whiteColor];
    //开是监听网络请求
    [MHURLProtocol startListeningNetWorking];
    
    _web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-40)];
    [self.view addSubview:_web];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com"]];
    [_web loadRequest:request];
    
    _openNoImageBtn = [UIButton buttonWithType:0];
    _openNoImageBtn.frame = CGRectMake(0, self.view.frame.size.height-40, self.view.frame.size.width/3, 40);
    [_openNoImageBtn setTitle:@"开启无图" forState:0];
    [_openNoImageBtn setTitleColor:[UIColor redColor] forState:0];
    [_openNoImageBtn addTarget:self action:@selector(openNoimage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_openNoImageBtn];
    
    _webBack = [UIButton buttonWithType:0];
    _webBack.frame = CGRectMake(self.view.frame.size.width/3, self.view.frame.size.height-40, self.view.frame.size.width/3, 40);
    [_webBack setTitle:@"后退" forState:0];
    [_webBack setTitleColor:[UIColor redColor] forState:0];
    [_webBack addTarget:self action:@selector(webBack) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_webBack];
    
    _webForward = [UIButton buttonWithType:0];
    _webForward.frame = CGRectMake(self.view.frame.size.width/3*2, self.view.frame.size.height-40, self.view.frame.size.width/3, 40);
    [_webForward setTitle:@"前进" forState:0];
    [_webForward setTitleColor:[UIColor redColor] forState:0];
    [_webForward addTarget:self action:@selector(webForward) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_webForward];
}
-(void)openNoimage
{
    if ([_openNoImageBtn.titleLabel.text isEqualToString:@"开启无图"]) {
        [_openNoImageBtn setTitle:@"关闭无图" forState:0];
        [MHURLProtocol openNoImage:YES];
    }else{
        [_openNoImageBtn setTitle:@"开启无图" forState:0];
        [MHURLProtocol openNoImage:NO];
    }
}
-(void)webBack
{
    if ([_web canGoBack]) {
        [_web goBack];
    }
}
-(void)webForward
{
    if ([_web canGoForward]) {
        [_web goForward];
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
