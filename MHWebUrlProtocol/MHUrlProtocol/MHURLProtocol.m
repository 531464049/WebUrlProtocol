//
//  MHURLProtocol.m
//  HZWebBrowser
//
//  Created by 马浩 on 2017/11/6.
//  Copyright © 2017年 HuZhang. All rights reserved.
//

#import "MHURLProtocol.h"

@interface MHUrlCacheConfig: NSObject

@property(nonatomic,assign)BOOL openNoImage;//是否开启无图模式，默认NO
@property (readwrite, nonatomic, strong) NSMutableDictionary *urlDict;//记录上一次url请求时间
@property (readwrite, nonatomic, assign) NSInteger updateInterval;//相同的url地址请求，相隔大于等于updateInterval才会发出后台更新的网络请求，小于的话不发出请求。
@property (readwrite, nonatomic, strong) NSURLSessionConfiguration *config;//config是全局的，所有的网络请求都用这个config
@property (readwrite, nonatomic, strong) NSOperationQueue *forgeroundNetQueue;
@property (readwrite, nonatomic, strong) NSOperationQueue *backgroundNetQueue;

@end

#define DefaultUpdateInterval 36000
@implementation MHUrlCacheConfig


- (NSInteger)updateInterval{
    if (_updateInterval == 0) {
        //默认后台更新的时间为36000秒
        _updateInterval = DefaultUpdateInterval;
    }
    return _updateInterval;
}

- (NSURLSessionConfiguration *)config{
    if (!_config) {
        _config = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    return _config;
}

- (NSMutableDictionary *)urlDict{
    if (!_urlDict) {
        _urlDict = [NSMutableDictionary dictionary];
    }
    return _urlDict;
}

- (NSOperationQueue *)forgeroundNetQueue{
    if (!_forgeroundNetQueue) {
        _forgeroundNetQueue = [[NSOperationQueue alloc] init];
        _forgeroundNetQueue.maxConcurrentOperationCount = 10;
    }
    return _forgeroundNetQueue;
}

- (NSOperationQueue *)backgroundNetQueue{
    if (!_backgroundNetQueue) {
        _backgroundNetQueue = [[NSOperationQueue alloc] init];
        _backgroundNetQueue.maxConcurrentOperationCount = 6;
    }
    return _backgroundNetQueue;
}

+ (instancetype)instance{
    static MHUrlCacheConfig *urlCacheConfig = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        urlCacheConfig = [[MHUrlCacheConfig alloc] init];
    });
    return urlCacheConfig;
}

- (void)clearUrlDict{
    [MHUrlCacheConfig instance].urlDict = nil;
}

@end


static NSString * const URLProtocolAlreadyHandleKey = @"mh_alreadyHandle";
static NSString * const checkUpdateInBgKey = @"mh_checkUpdateInBg";

@interface MHURLProtocol()

@property (readwrite, nonatomic, strong) NSURLSession *session;
@property (readwrite, nonatomic, strong) NSMutableData *data;
@property (readwrite, nonatomic, strong) NSURLResponse *response;

@end

@implementation MHURLProtocol

+ (void)startListeningNetWorking{
    [NSURLProtocol registerClass:[MHURLProtocol class]];
}

+ (void)cancelListeningNetWorking{
    [NSURLProtocol unregisterClass:[MHURLProtocol class]];
}
+(void)openNoImage:(BOOL)open
{
    [[MHUrlCacheConfig instance] setOpenNoImage:open];
}
+ (void)setConfig:(NSURLSessionConfiguration *)config{
    [[MHUrlCacheConfig instance] setConfig:config];
}

+ (void)setUpdateInterval:(NSInteger)updateInterval{
    [[MHUrlCacheConfig instance] setUpdateInterval:updateInterval];
}

+ (void)clearUrlDict{
    [[MHUrlCacheConfig instance] clearUrlDict];
}
#pragma mark - 请求是否需要拦截（只拦截图片及资源类）
+(BOOL)mh_shouldInterceptRequest:(NSURLRequest *)request
{
    if (request.URL.absoluteString.length > 0) {
        // 不拦截post请求
        if (request.HTTPMethod && [request.HTTPMethod.uppercaseString isEqualToString:@"POST"]) {
            return NO;
        }
        NSString *urlScheme = [[request URL] scheme];
        if ([urlScheme caseInsensitiveCompare:@"http"] == NSOrderedSame || [urlScheme caseInsensitiveCompare:@"https"] == NSOrderedSame){
            
            if ([MHURLProtocol mh_requestIsImageRequest:request]) {
                //判断是否是图片资源
                return YES;
            }
            //判断是否是其他资源css , js
            BOOL isCssJs = NO;
            NSArray * cssjsKeyArr = @[@"css", @"js"];
            for (NSString * key in cssjsKeyArr) {
                isCssJs = [request.URL.pathExtension caseInsensitiveCompare:key]  == NSOrderedSame;
                if (isCssJs) {
                    break;
                }
            }
            if (!isCssJs) {
                NSArray * urlParr = [request.URL.absoluteString componentsSeparatedByString:@"."];
                if (urlParr.count > 0) {
                    NSString * lastP = [urlParr lastObject];
                    for (NSString * key in cssjsKeyArr) {
                        isCssJs = [lastP caseInsensitiveCompare:key]  == NSOrderedSame;
                        if (isCssJs) {
                            break;
                        }
                    }
                }
            }
            return isCssJs;
        }
        return NO;
    }
    return NO;
}
#pragma mark - 判断是否是图片请求
+(BOOL)mh_requestIsImageRequest:(NSURLRequest *)request
{
    //先判断extension是否是图片格式
    NSString* extension = request.URL.pathExtension;
    BOOL isImage = NO;
    NSArray * imgKeyArr = @[@"png", @"jpeg", @"gif", @"jpg"];
    for (NSString * key in imgKeyArr) {
        isImage = [extension caseInsensitiveCompare:key]  == NSOrderedSame;
        if (isImage) {
            break;
        }
    }
    if (!isImage) {//如果上边为判断出图片，继续判断url最后一段格式
        NSArray * urlParr = [request.URL.absoluteString componentsSeparatedByString:@"."];
        if (urlParr.count > 0) {
            NSString * lastP = [[urlParr lastObject] lowercaseString];
            for (NSString * key in imgKeyArr) {
                isImage =[lastP containsString:key];
                if (isImage) {
                    break;
                }
//                isImage = [lastP caseInsensitiveCompare:key]  == NSOrderedSame;
//                if (isImage) {
//                    break;
//                }
            }
        }
    }
    return isImage;
}
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{
    NSLog(@"=== %@ ===",request.URL.absoluteString);
//    NSLog(@"=== %@ ===",request.URL.pathExtension);
    if ([MHURLProtocol mh_shouldInterceptRequest:request.mutableCopy]) {
        //判断是否标记过使用缓存来处理，或者是否有标记后台更新
        if ([NSURLProtocol propertyForKey:URLProtocolAlreadyHandleKey inRequest:request] || [NSURLProtocol propertyForKey:checkUpdateInBgKey inRequest:request]) {
            return NO;
        }
        return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{
    return request;
}

- (void)backgroundCheckUpdate{
    __weak typeof(self) weakSelf = self;
    [[[MHUrlCacheConfig instance] backgroundNetQueue] addOperationWithBlock:^{
        NSDate *updateDate = [[MHUrlCacheConfig instance].urlDict objectForKey:weakSelf.request.URL.absoluteString];
        if (updateDate) {
            //判读两次相同的url地址发出请求相隔的时间，如果相隔的时间小于给定的时间，不发出请求。否则发出网络请求
            NSDate *currentDate = [NSDate date];
            NSInteger interval = [currentDate timeIntervalSinceDate:updateDate];
            if (interval < [MHUrlCacheConfig instance].updateInterval) {
                return;
            }
        }
        NSMutableURLRequest *mutableRequest = [[weakSelf request] mutableCopy];
        [NSURLProtocol setProperty:@YES forKey:checkUpdateInBgKey inRequest:mutableRequest];
        [weakSelf netRequestWithRequest:mutableRequest];
        
    }];
}

- (void)netRequestWithRequest:(NSURLRequest *)request{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[MHUrlCacheConfig instance].forgeroundNetQueue];
    NSURLSessionDataTask * sessionTask = [self.session dataTaskWithRequest:request];
    [[MHUrlCacheConfig instance].urlDict setValue:[NSDate date] forKey:self.request.URL.absoluteString];
    [sessionTask resume];
}


- (void)startLoading{
    NSCachedURLResponse *urlResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:[self request]];
    if (urlResponse) {
        //如果缓存存在，则使用缓存。并且开启异步线程去更新缓存
//        NSLog(@"使用缓存数据");
        [self.client URLProtocol:self didReceiveResponse:urlResponse.response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:urlResponse.data];
        [self.client URLProtocolDidFinishLoading:self];
        
        if ([MHUrlCacheConfig instance].openNoImage && [MHURLProtocol mh_requestIsImageRequest:[[self request] mutableCopy]]) {
            //如果开启了无图模式 且请求是图片请求
            return;
        }
        [self backgroundCheckUpdate];
    }else{
        NSMutableURLRequest *mutableRequest = [[self request] mutableCopy];
        [NSURLProtocol setProperty:@YES forKey:URLProtocolAlreadyHandleKey inRequest:mutableRequest];
        //如果开启了无图模式
        if ([MHUrlCacheConfig instance].openNoImage) {
            if ([MHURLProtocol mh_requestIsImageRequest:mutableRequest]) {
                UIImage * img = [UIImage imageNamed:@"web_no_pic"];
                NSData* data = UIImagePNGRepresentation(img);
                NSURLResponse* response = [[NSURLResponse alloc] initWithURL:self.request.URL MIMEType:@"image/png" expectedContentLength:data.length textEncodingName:nil];
                [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                [self.client URLProtocol:self didLoadData:data];
                [self.client URLProtocolDidFinishLoading:self];
                return;
            }
        }
        
        [self netRequestWithRequest:mutableRequest];
    }
}
- (void)stopLoading{
    [self.session invalidateAndCancel];
    self.session = nil;
}

- (BOOL)isUseCache{
    //如果有缓存则使用缓存，没有缓存则发出请求
    NSCachedURLResponse *urlResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:[self request]];
    if (urlResponse) {
        return YES;
    }
    return NO;
}

- (void)appendData:(NSData *)newData
{
    if ([self data] == nil) {
        [self setData:[newData mutableCopy]];
    }
    else {
        [[self data] appendData:newData];
    }
}
#pragma mark -NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self.client URLProtocol:self didLoadData:data];
    
    [self appendData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    self.response = response;
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
        if (!self.data) {
            return;
        }
        NSCachedURLResponse *cacheUrlResponse = [[NSCachedURLResponse alloc] initWithResponse:task.response data:self.data];
        [[NSURLCache sharedURLCache] storeCachedResponse:cacheUrlResponse forRequest:self.request];
        self.data = nil;
    }
}

@end
