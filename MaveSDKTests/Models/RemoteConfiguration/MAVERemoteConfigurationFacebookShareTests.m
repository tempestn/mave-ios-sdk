//
//  MAVERemoteConfigurationFacebookShareTests.m
//  MaveSDK
//
//  Created by Danny Cosson on 1/11/15.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "MAVERemoteConfigurationFacebookShare.h"

@interface MAVERemoteConfigurationFacebookShareTests : XCTestCase

@end

@implementation MAVERemoteConfigurationFacebookShareTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDefaultData {
    NSDictionary *defaults = [MAVERemoteConfigurationFacebookShare defaultJSONData];
    NSDictionary *template = [defaults objectForKey:@"template"];
    XCTAssertNotNil(template);

    XCTAssertEqualObjects([template objectForKey:@"template_id"], @"0");
    XCTAssertEqualObjects([template objectForKey:@"copy"], @"I love DemoApp. You should try it. ");
}

- (void)testInitFromDefaultData {
    MAVERemoteConfigurationFacebookShare *obj = [[MAVERemoteConfigurationFacebookShare alloc] initWithDictionary:[MAVERemoteConfigurationFacebookShare defaultJSONData]];

    XCTAssertEqualObjects(obj.templateID, @"0");
    XCTAssertEqualObjects(obj.text, @"I love DemoApp. You should try it. ");
}

- (void)testInitFailsIfTemplateMalformed {
    // missing the "copy" parameter
    NSDictionary *data = @{@"template_id": @"foo"};
    MAVERemoteConfigurationFacebookShare *obj = [[MAVERemoteConfigurationFacebookShare alloc] initWithDictionary:data];

    XCTAssertNil(obj);
}

@end