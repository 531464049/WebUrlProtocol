//
//  MHURLProtocol.h
//  HZWebBrowser
//
//  Created by 马浩 on 2017/11/6.
//  Copyright © 2017年 HuZhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MHURLProtocol : NSURLProtocol<NSURLSessionDataDelegate>

@property (readwrite, nonatomic, strong) NSURLSessionConfiguration *config;//config是全局的，所有的网络请求都用这个config

@property (readwrite, nonatomic, assign) NSInteger updateInterval;//相同的url地址请求，相隔大于等于updateInterval才会发出后台更新的网络请求，小于的话不发出请求。

/**
 开始监听网络请求
 */
+ (void)startListeningNetWorking;

/**
 取消监听
 */
+ (void)cancelListeningNetWorking;


/**
 是否开启无图模式

 @param open 开启/关闭
 */
+(void)openNoImage:(BOOL)open;

+ (void)setConfig:(NSURLSessionConfiguration *)config;//config是全局的，所有的网络请求都用这个config，参见NSURLSession使用的NSURLSessionConfiguration
+ (void)setUpdateInterval:(NSInteger)updateInterval;//相同的url地址请求，相隔大于等于updateInterval才会发出后台更新的网络请求，小于的话不发出请求。默认是36000秒，10个小时
+ (void)clearUrlDict;//收到内存警告的时候可以调用这个方法清空内存中的url记录

@end
