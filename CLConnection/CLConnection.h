// Copyright (c) 2016 Jaeha Kim
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// v2.1.0
// Compliance to iOS 9.0+ new APIs

#import <Foundation/Foundation.h>

#ifndef CLCONN_OBJ
#define CLCONN_OBJ @"connectionObj"
#endif

#ifndef CLCONN_RESULT_DATA
#define CLCONN_RESULT_DATA @"resultData"
#endif

#ifndef CLCONN_DATA
#define CLCONN_DATA @"data"
#endif

@protocol CLConnectionDelegate <NSObject>

@required
- (void)connectionFailed:(id)sender;
@end

/* Request Method Setup */
typedef enum {
	kCLRequestMethodGET,        // Default
	kCLRequestMethodPOST,
}kCLRequestMethod;

/* ReceiveType Setup */
typedef enum {
	kCLReceiveTypeJSON,         // Default
	kCLReceiveTypeString,
}kCLReceiveType;

typedef enum {
	kCLRequestBodyTypeFormData,         // Default
	kCLRequestBodyTypeApplicationJSON,
}kCLRequestBodyType;

@interface CLConnection : NSObject
{
	
}

@property (nonatomic, copy) void (^completitionBlock) (id obj, NSError * error);
@property (nonatomic, copy) void (^failedBlock) (NSError* error);
@property (nonatomic, assign) kCLRequestBodyType reqBodyType;
@property (nonatomic, strong) NSDictionary* userInfo;

/*** Class Helper Methods ***/

/** Class Method : NSNotification Data Helper
 Will return NSDictionary if kCLReceiveType = JSON
 Will return NSString if kCLReceiveType = String
 May return nil! */
+ (id)openNotificationData:(NSNotification*)notification;
/** Class Method : returns CLConnection from NSNotification
 May return nil! */
+ (CLConnection*)getCLConnectionFromNotification:(NSNotification*)notification;

/** uses NSNotification to send received data
 default is YES */
- (void)setUsesNSNotification:(BOOL)yn;

/*** Delegate Methods to use predefined Protocol  ***/

/** sets target and selector */
- (void)setDelegate:(id)aTarget selector:(SEL)selector;
/** sets target and selector, failed selector */
- (void)setDelegate:(id)aTarget selector:(SEL)selector failSelector:(SEL)failSelector;

/** kCLReceiveTypeJSON returns parsed JSON into a NSDictionary othwerwise returns NSString */
- (void)setReceiveDataType:(kCLReceiveType)type;

/*** Request Creator ***/

/** Request Async Connection default Method is GET.
	Setting the nameTag will enable NSNotification Receiver */
- (BOOL)requestUrl:(NSString *)url bodyObject:(NSDictionary *)bodyObject name:(NSString*)nameTag;
/** Request Async Connection default Method is GET.
	Setting the nameTag will enable NSNotification Receiver */
- (BOOL)requestUrl:(NSString *)url bodyObject:(NSDictionary *)bodyObject requestMethod:(kCLRequestMethod)requestMethod name:(NSString*)nameTag;
/** Request Async Connection default Method is GET.
	Setting the nameTag will enable NSNotification Receiver.
	Use userInfo for Notification:userInfo */
- (BOOL)requestUrl:(NSString *)url bodyObject:(NSDictionary *)bodyObject requestMethod:(kCLRequestMethod)requestMethod name:(NSString*)nameTag userInfo:(NSDictionary*)uInfo;


@end

