/*
The MIT License (MIT)

Copyright (c) 2016 Jaeha Kim

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE

 */
//
// v2.1.0
// Compliance to iOS 9.0+ new APIs
//
#import "CLConnection.h"
#import <UIKit/UIKit.h>
#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)




@interface CLConnection ()

@property (nonatomic, strong) id<CLConnectionDelegate> delegate;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) SEL failSelector;
@property (nonatomic, assign) kCLReceiveType recvType;

@property (nonatomic, assign) BOOL usesNSNotification;
@property (nonatomic, strong) NSMutableData* receivedData;
@property (nonatomic, strong) NSString* nameTag;
@property (nonatomic, assign) id target;



@end




@implementation CLConnection

@synthesize target= _target, selector = _selector, failSelector =_failSelector;
@synthesize recvType=_recvType;
@synthesize userInfo=_userInfo;
@synthesize nameTag=_nameTag;
@synthesize receivedData=_receivedData;



/** Class Method : NSNotification Data Helper */
+ (id)openNotificationData:(NSNotification*)notification{
	if ( [notification userInfo] ){
		id retData = [[notification userInfo]objectForKey:CLCONN_DATA];
		CLConnection* conn = [CLConnection getCLConnectionFromNotification:notification];
		if ( conn ){
			if ( [retData isKindOfClass:[NSString class]]){
				NSString* retStr = (NSString*)retData;
				return retStr;
			}else if ( [retData isKindOfClass:[NSDictionary class]] ){
				NSDictionary* retDict = (NSDictionary*)retData;
				return retDict;
			}else {
				return nil;
			}
		}
	}
	return nil;
}

+ (CLConnection*)getCLConnectionFromNotification:(NSNotification*)notification{
	if ( [notification userInfo] ){
		return [[notification userInfo] objectForKey:@"connectionObj"];
	}
	return nil;
}


-(id)init{
	if(self=[super init]){
		_selector = nil;
		_failSelector = nil;
		_receivedData = nil;
		_nameTag = nil;
		// default receive type
		_recvType = kCLReceiveTypeJSON;
		_reqBodyType = kCLRequestBodyTypeFormData;
		// default YES
		_usesNSNotification = YES;
		_userInfo = nil;
	}
	return self;
}


- (void)setDelegate:(id)target selector:(SEL)selector{
	self.target = target;
	self.selector = selector;
	self.failSelector = nil;
}

- (void)setDelegate:(id)target selector:(SEL)selector failSelector:(SEL)failSelector{
	if ( !target ){
		NSAssert(0, @"CLConnection Target must be not nil.");
	}
	self.target = target;
	self.selector = selector;
	self.failSelector = failSelector;
}

- (void)setReceiveDataType:(kCLReceiveType)type{
	_recvType = type;
}

- (void)dealloc{
#if !(__has_feature(objc_arc))
	[super dealloc];
	if ( _receivedData) [_receivedData release];
	if ( _nameTag ) [_nameTag release];
	if ( _delegate ) [_delegate release];
#endif
	_receivedData = nil;
	_nameTag = nil;
	_delegate = nil;
}


- (BOOL)requestUrl:(NSString *)url bodyObject:(NSDictionary *)bodyObject name:(NSString*)nameTag
{
	return [self requestUrl:url bodyObject:bodyObject requestMethod:kCLRequestMethodGET name:nameTag];
}
- (BOOL)requestUrl:(NSString *)url bodyObject:(NSDictionary *)bodyObject requestMethod:(kCLRequestMethod)requestMethod name:(NSString*)nameTag{
	return [self requestUrl:url bodyObject:bodyObject requestMethod:requestMethod name:nameTag userInfo:nil];
}
- (BOOL)requestUrl:(NSString *)url bodyObject:(NSDictionary *)bodyObject requestMethod:(kCLRequestMethod)requestMethod name:(NSString*)nameTag userInfo:(NSDictionary*)uInfo{
	if ( uInfo ){
		self.userInfo = uInfo;
	}
	
	if ( nameTag ){
		_nameTag = [[NSString alloc] initWithString:nameTag];
#if !(__has_feature(objc_arc))
		[_nameTag retain];
#endif
	}
	//	NSLog(@"url : %@", url);
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
														   cachePolicy:NSURLRequestUseProtocolCachePolicy
													   timeoutInterval:4.0f];
//	NSString*userAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/8.0 Mobile/11A465 Safari/9537.53";
//	[request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	
	// 통신방식 정의 (POST, GET)
	if (requestMethod == kCLRequestMethodGET){
		[request setHTTPMethod:@"GET"];
	}else if (requestMethod==kCLRequestMethodPOST){
		[request setHTTPMethod:@"POST"];
	}else {
		// default = GET
		[request setHTTPMethod:@"GET"];
	}
	
	// bodyObject의 객체가 존재할 경우 QueryString형태로 변환
	if(_reqBodyType == kCLRequestBodyTypeFormData ){
		[request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
		if(bodyObject)
		{
			// 임시 변수 선언
			NSMutableArray *parts = [NSMutableArray array];
			NSString *part;
			id key;
			id value;
			
			// 값을 하나하나 변환
			for(key in bodyObject)
			{
				
				value = [bodyObject objectForKey:key];
				if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0")){
					
					part = [NSString stringWithFormat:@"%@=%@", [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
							[value stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
				}else{
#ifndef __IPHONE_9_0
					part = [NSString stringWithFormat:@"%@=%@", [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
							[value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
#endif
				}
				if(part!=nil) [parts addObject:part];
			}
			
			// 값들을 &로 연결하여 Body에 사용
			[request setHTTPBody:[[parts componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding]];
		}
	}else if ( _reqBodyType == kCLRequestBodyTypeApplicationJSON ){
		NSError* err=  nil;
		NSData* jsonData = [NSJSONSerialization dataWithJSONObject:bodyObject options:kNilOptions error:&err];
		[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		[request setHTTPBody:jsonData];
	}
	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0")){
	// Request를 사용하여 실제 연결을 시도하는 NSURLConnection 인스턴스 생성
	NSURLSessionDataTask* connection = [[NSURLSession sharedSession] dataTaskWithRequest:request
																	   completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if(data){
			_receivedData = [NSMutableData dataWithData:data];
			if ( self.completitionBlock ){
				self.completitionBlock([self parseReceivedData], nil);
			}
		}else{
			if ( self.completitionBlock ){
				self.completitionBlock(nil, error);
			}
		}
		if ( self.failedBlock ){
		   self.failedBlock(error);
		}
	}];
		if(connection){
			[connection resume];
			_receivedData = [[NSMutableData alloc] init];
		}
	}else{
#ifndef __IPHONE_9_0
		NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		// 정상적으로 연결이 되었다면
		if(connection)
		{
			// 데이터를 전송받을 멤버 변수 초기화
			_receivedData = [[NSMutableData alloc] init];
			return YES;
		}else{
			// 연결 실패.
			//        NSLog(@"Conn Fail: %@", _nameTag);
			if ( [self.target respondsToSelector:@selector(connectionFailed:)] ){
				[self.target connectionFailed:nil];
			}
			if ( self.failedBlock ){
				self.failedBlock(error);
			}
		}
#endif
	}
	return NO;
}


- (NSDictionary*)parseReceivedData{
	if ( _recvType == kCLReceiveTypeJSON ){
		NSError* err = nil;
		NSDictionary* d = [NSJSONSerialization JSONObjectWithData:_receivedData options:NSJSONReadingMutableContainers|NSJSONReadingAllowFragments error:&err];
		if ( err == nil ){
			return d;
		}else{
			
			NSLog(@"Data for %@ = %@", _nameTag, [[NSString alloc] initWithData:_receivedData encoding:NSUTF8StringEncoding]);
			return @{@"error":@"JSON Parse Error.", @"errorInfo":[err localizedDescription]};
		}
	}return nil;
}


#pragma mark -


- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse *)response{
	[_receivedData setLength:0];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData *)data{
	[_receivedData appendData:data];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError *)error{
	//    NSLog(@"Conn Fail: %@, REASON: %@", _nameTag, [error localizedDescription]);
	if(self.target){
		if(self.selector){
			if ( [self.target respondsToSelector:self.failSelector]){
				IMP imp = [self.target methodForSelector:self.selector];
				void (*func)(id, SEL) = (void *)imp;
				func(self.target, self.failSelector);
			}
		}
	}
	self.target = nil;
	self.selector = nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@_F",_nameTag] object:nil userInfo:nil];
	
	if ( self.failedBlock ){
		self.failedBlock(error);
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection{
	
	// Delegate 존재
	if(self.target){
		if([self.target respondsToSelector:self.selector]){
			// ARC 호환되는 콜백 함수
			IMP imp = [self.target methodForSelector:self.selector];
			void (*func)(id, SEL, NSData*) = (void *)imp;
			func(self.target, self.selector, _receivedData);
		}
	}
	self.target = nil;
	self.selector = nil;
	
//	NSLog(@"data for [%@] %@ = %@", 	connection.currentRequest.URL.absoluteString, _nameTag, [[NSString alloc] initWithData:_receivedData encoding:NSUTF8StringEncoding]);
	id notiData = nil;
	
	if ( _recvType == kCLReceiveTypeJSON ){
		NSError* err = nil;
		NSDictionary* d = [NSJSONSerialization JSONObjectWithData:_receivedData options:NSJSONReadingMutableContainers|NSJSONReadingAllowFragments error:&err];
		if ( err == nil ){
			notiData = d;
		}else{
			NSLog(@"data for [%@] %@ = %@", 	connection.currentRequest.URL.absoluteString, _nameTag, [[NSString alloc] initWithData:_receivedData encoding:NSUTF8StringEncoding]);
			notiData = @{@"error":@"JSON Parse Error.", @"errorInfo":[err localizedDescription]};
		}
	}else {
		notiData = _receivedData;
	}
	
	if ( _nameTag && _usesNSNotification ){
		NSDictionary* uInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
							   notiData,CLCONN_RESULT_DATA,
							   self,CLCONN_OBJ,
							   nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:_nameTag object:nil userInfo:uInfo];
	}
	
	if ( self.completitionBlock ){
		self.completitionBlock(notiData, nil);
	}
}


@end


