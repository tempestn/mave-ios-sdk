//
//  MAVEHTTPStackTests.m
//  MaveSDK
//
//  Created by Danny Cosson on 1/2/15.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <OCMock/OCMock.h>
#import "MAVEConstants.h"
#import "MAVEHTTPStack.h"
#import "MAVECompressionUtils.h"

typedef void (^MAVENSURLSessionCallback)(NSData *data, NSURLResponse *response, NSError *error);

// NSURLSessionTask is doing something weird, we can't just extend it to make originalRequest readwrite
// or mock it bceause ios thinks the method doesn't exist. So use this fake version instead.

@interface FakeNSURLSessionTaskForTestingRedirect : NSObject
@property (strong, nonatomic, readwrite) NSURLRequest *originalRequest;
@end

@implementation FakeNSURLSessionTaskForTestingRedirect
@end


@interface MAVEHTTPStackTests : XCTestCase

@property (nonatomic, strong) MAVEHTTPStack *testHTTPStack;

@end

@implementation MAVEHTTPStackTests

- (void)setUp {
    [super setUp];
    self.testHTTPStack = [[MAVEHTTPStack alloc] initWithAPIBaseURL:@"https://foo.example.com"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInit {
    XCTAssertEqualObjects(self.testHTTPStack.baseURL, @"https://foo.example.com");
    XCTAssertNotNil(self.testHTTPStack.session);
    XCTAssertNotNil(self.testHTTPStack.session.delegateQueue);
    XCTAssertNil(self.testHTTPStack.session.configuration.HTTPAdditionalHeaders);
    XCTAssertEqual(self.testHTTPStack.session.configuration.requestCachePolicy,
                   NSURLRequestUseProtocolCachePolicy);
    XCTAssertEqual(self.testHTTPStack.session.configuration.timeoutIntervalForRequest, 10.0);
    XCTAssertEqual(self.testHTTPStack.session.configuration.timeoutIntervalForResource, 10.0);
    XCTAssertNotNil(self.testHTTPStack.requestLoggingBlock);
}


- (void)testPrepareJSONRequestWithBodySuccess {
    // Non GET & delete requests should have params as request body json formatted
    NSString *path = @"/foo";
    NSDictionary *params = @{@"foo": @2, @"bar": @YES, @"baz": @"hello"};
    NSString *method = @"POST";
    NSError *error = nil;
    NSMutableURLRequest *request = [self.testHTTPStack prepareJSONRequestWithRoute:path
                                                                        methodName:method
                                                                            params:params
                                                                   contentEncoding:MAVEHTTPRequestContentEncodingDefault
                                                                  preparationError:&error];
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(request.URL, [[NSURL alloc] initWithString:@"https://foo.example.com/foo"]);
    XCTAssertEqualObjects(request.HTTPMethod, method);
    XCTAssertEqualObjects([NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil],
                          params);
    NSDictionary *expectedHeaders = @{@"Content-Type": @"application/json; charset=utf-8",
                                      @"Accept": @"application/json",
                                      };
    XCTAssertEqualObjects(request.allHTTPHeaderFields, expectedHeaders);
}

- (void)testPrepareJSONRequestGzippedWithBodySuccess {
    // Non GET & delete requests should have params as request body json formatted
    NSString *path = @"/foo";
    NSDictionary *params = @{@"foo": @2, @"bar": @YES, @"baz": @"hello"};
    NSString *method = @"POST";
    NSError *error = nil;
    NSMutableURLRequest *request = [self.testHTTPStack prepareJSONRequestWithRoute:path
                                                                        methodName:method
                                                                            params:params
                                                                   contentEncoding:MAVEHTTPRequestContentEncodingGzip
                                                                  preparationError:&error];
    XCTAssertNil(error);

    XCTAssertEqualObjects(request.URL, [[NSURL alloc] initWithString:@"https://foo.example.com/foo"]);
    XCTAssertEqualObjects(request.HTTPMethod, method);
    NSData *uncompressed = [MAVECompressionUtils gzipUncompressData:request.HTTPBody];
    NSDictionary *bodyDict = [NSJSONSerialization JSONObjectWithData:uncompressed options:0 error:nil];
    XCTAssertEqualObjects(bodyDict, params);
    NSDictionary *expectedHeaders = @{@"Content-Type": @"application/json; charset=utf-8",
                                      @"Content-Encoding": @"gzip",
                                      @"Accept": @"application/json",
                                      };
    XCTAssertEqualObjects(request.allHTTPHeaderFields, expectedHeaders);
}

- (void)testPrepareJSONRequestGzippedEmptyParamsSuccess {
    // a POST request with no params passed in should still be json formatted (meaning empty dict)
    // and should still get gzip encoded if that's the encoding specified
    NSString *path = @"/foo";
    NSString *method = @"POST";
    NSError *error = nil;
    NSMutableURLRequest *request = [self.testHTTPStack prepareJSONRequestWithRoute:path
                                                                        methodName:method
                                                                            params:@{}
                                                                   contentEncoding:MAVEHTTPRequestContentEncodingGzip
                                                                  preparationError:&error];
    XCTAssertNil(error);

    XCTAssertEqualObjects(request.URL, [[NSURL alloc] initWithString:@"https://foo.example.com/foo"]);
    XCTAssertEqualObjects(request.HTTPMethod, method);
    NSData *uncompressed = [MAVECompressionUtils gzipUncompressData:request.HTTPBody];
    NSDictionary *bodyDict = [NSJSONSerialization JSONObjectWithData:uncompressed options:0 error:nil];
    XCTAssertEqualObjects(bodyDict, @{});
    NSDictionary *expectedHeaders = @{@"Content-Type": @"application/json; charset=utf-8",
                                      @"Content-Encoding": @"gzip",
                                      @"Accept": @"application/json",
                                      };
    XCTAssertEqualObjects(request.allHTTPHeaderFields, expectedHeaders);
}

- (void)testPrepareJSONGETBodySuccess {
    // GET requests should have no body. Gzip encoding doesn't matter b/c it's get request
    // so body is empty and it shouldn't gzip encode
    NSString *path = @"/foo";
    NSDictionary *params = @{@"foo": @2, @"bar": @YES, @"baz": @"hello", @"bae":@[@"a", @1]};
    NSString *method = @"GET";
    NSError *error = nil;
    NSMutableURLRequest *request = [self.testHTTPStack prepareJSONRequestWithRoute:path
                                                                        methodName:method
                                                                            params:params
                                                                   contentEncoding:MAVEHTTPRequestContentEncodingGzip
                                                                  preparationError:&error];
    XCTAssertNil(error);

    // note array params get joined with commas
    NSString *expectedURL = @"https://foo.example.com/foo?bae=a,1&bar=1&baz=hello&foo=2";
    XCTAssertEqualObjects(request.URL, [[NSURL alloc] initWithString:expectedURL]);
    XCTAssertEqualObjects(request.HTTPMethod, method);
    XCTAssertEqualObjects(request.HTTPBody, [@"" dataUsingEncoding:NSUTF8StringEncoding]);
    NSDictionary *expectedHeaders = @{@"Content-Type": @"application/json; charset=utf-8",
                                      @"Accept": @"application/json",
                                      };
    XCTAssertEqualObjects(request.allHTTPHeaderFields, expectedHeaders);
}

- (void)testRedirects {
    NSMutableURLRequest *originalRequest = [[NSMutableURLRequest alloc] init];
    originalRequest.URL = [NSURL URLWithString:@"http://example.com/foo"];
    originalRequest.HTTPMethod = @"POST";
    originalRequest.HTTPBody = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
    [originalRequest setValue:@"foobar" forHTTPHeaderField:@"X-Danny-Foo"];
    
    // This is a new request with basically what the default behavior for redirects would be
    NSMutableURLRequest *newRequest = [[NSMutableURLRequest alloc] init];
    newRequest.URL = [NSURL URLWithString:@"https://example.com/foo"];
    newRequest.HTTPMethod = @"GET";
    newRequest.HTTPBody = nil;
    [originalRequest setValue:@"foobar" forHTTPHeaderField:@"X-Danny-Foo"];

    FakeNSURLSessionTaskForTestingRedirect *task = [[FakeNSURLSessionTaskForTestingRedirect alloc] init];
    task.originalRequest = originalRequest;
    id fakeResponse = OCMClassMock([NSHTTPURLResponse class]);
    
    [self.testHTTPStack URLSession:self.testHTTPStack.session
                              task:(NSURLSessionTask *)task
        willPerformHTTPRedirection:fakeResponse
                        newRequest:newRequest
                 completionHandler:^(NSURLRequest * request) {
        XCTAssertEqualObjects(request.URL, newRequest.URL);
        XCTAssertEqualObjects(request.HTTPMethod, originalRequest.HTTPMethod);
        XCTAssertEqualObjects(request.HTTPBody, originalRequest.HTTPBody);
        XCTAssertEqualObjects(request.allHTTPHeaderFields, originalRequest.allHTTPHeaderFields);
    }];
}


//
// Tests for errors in building Request
//
- (void)testPrepareRequestWithBadJSONfails {
    // Object is invalid for JSON
    NSDictionary *badParams = nil;
    NSError *error;
    
    NSMutableURLRequest *request = [self.testHTTPStack prepareJSONRequestWithRoute:@"/foo"
                                                                        methodName:@"POST"
                                                                            params:badParams
                                                                   contentEncoding:MAVEHTTPRequestContentEncodingDefault
                                                                  preparationError:&error];
    XCTAssertNil(request);
    XCTAssertEqual([error code], MAVEHTTPErrorRequestJSONCode);
}


- (void)testPrepareRequestWithInternalJSONFailure {
    Method ogMethod = class_getClassMethod([NSJSONSerialization class], @selector(dataWithJSONObject:options:error:));
    Method mockMethod = class_getInstanceMethod([self class], @selector(failingDataWithJSONObject:options:error:));
    method_exchangeImplementations(ogMethod, mockMethod);
    
    NSError *error;
    NSMutableURLRequest *request =  [self.testHTTPStack prepareJSONRequestWithRoute:@"/foo"
                                                                         methodName:@"POST"
                                                                             params:@{}
                                                                    contentEncoding:MAVEHTTPRequestContentEncodingDefault
                                                                   preparationError:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(request);
    method_exchangeImplementations(mockMethod, ogMethod);
}
- (NSData *)failingDataWithJSONObject:(id)params options:(NSJSONWritingOptions)options error:(NSError **)error {
    if (error != NULL) { *error = [[NSError alloc] init]; }
    return nil;
}

///
/// Tests for response handler
///
- (void)testHandleSuccessJSONResponseWithData {
    NSDictionary *dataDict = @{@"foo": @2, @"bar": @"yes", @"baz": @YES};
    NSData *data = [NSJSONSerialization dataWithJSONObject:dataDict options:kNilOptions error:nil];
    
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:headers];
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [self.testHTTPStack handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, dataDict);
    XCTAssertEqualObjects(returnedError, nil);
}

- (void) testHandleEmptyStringResponseBody {
    // Empty string
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:headers];
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [self.testHTTPStack handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, @{});
    XCTAssertEqualObjects(returnedError, nil);
    
    // Literal double quotes in string
    data = [@"\"\"\n" dataUsingEncoding:NSUTF8StringEncoding];
    [self.testHTTPStack handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, @{});
    XCTAssertEqualObjects(returnedError, nil);
    
    // data nil
    data = nil;
    [self.testHTTPStack handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, @{});
    XCTAssertEqualObjects(returnedError, nil);
}

- (void)testHandleInvalidJSONResponse {
    NSData *data = [@"{\"this is not json" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:headers];
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [self.testHTTPStack handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorResponseJSONCode);
}

- (void)testHandleNonJSONResponse {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{} options:kNilOptions error:nil];
    
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"text/html"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:headers];
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [self.testHTTPStack handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorResponseIsNotJSONCode);
}

- (void)testHandle400LevelResponse {
    // Authentication Errors and the like
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:401 HTTPVersion:@"1.1" headerFields:headers];
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [self.testHTTPStack handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], 401);
}

- (void)testHandle500LevelResponse {
    // Authentication Errors and the like
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:504 HTTPVersion:@"1.1" headerFields:headers];
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [self.testHTTPStack handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], 504);
}

- (void)testHandleNilResponse {
    // Authentication Errors and the like
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *response = nil;
    
    __block NSDictionary *returnedData;
    __block NSError *returnedError;
    [self.testHTTPStack handleJSONResponseWithData:data response:response error:nil completionBlock:^(NSError *error, NSDictionary *responseData) {
        returnedError = error;
        returnedData = responseData;
    }];
    XCTAssertEqualObjects(returnedData, nil);
    XCTAssertEqual([returnedError code], MAVEHTTPErrorResponseNilCode);
}

- (void)testHandleResponseWithNilCompletionBlockDoesNothing {
    NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:@"http://example.com/foo"];
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:504 HTTPVersion:@"1.1" headerFields:headers];
    
    // Shouldn't throw an error
    [self.testHTTPStack handleJSONResponseWithData:data
                                       response:response
                                          error:nil
                                completionBlock:nil];
}

///
/// Test for data conversion util methods
///
- (void)testStatusCodeLevel {
    XCTAssertEqual([MAVEHTTPStack statusCodeLevel:200], 2);
    XCTAssertEqual([MAVEHTTPStack statusCodeLevel:201], 2);
    XCTAssertEqual([MAVEHTTPStack statusCodeLevel:299], 2);
    XCTAssertEqual([MAVEHTTPStack statusCodeLevel:500], 5);
}

- (void)testDictToURLParams {
    NSString *qs = [MAVEHTTPStack dictToURLQueryStringFragment:@{
                                                                 @"b": @NO,
                                                                 @"a": @YES,
                                                                 @"c": @"simplestring",
                                                                 @"d": @"escaped ?-",
                                                                 @"e": @2,
                                                                 @"f": @"2",
                                                                 @"g": [NSNull null]}];
    NSString *expected = @"?a=1&b=0&c=simplestring&d=escaped%20%3F-&e=2&f=2&g=";
    XCTAssertEqualObjects(qs, expected);
}

- (void)testEmptyDictToURLGivesEmptyString {
    XCTAssertEqualObjects([MAVEHTTPStack dictToURLQueryStringFragment:nil], @"");
    XCTAssertEqualObjects([MAVEHTTPStack dictToURLQueryStringFragment:@{}], @"");
}




@end
