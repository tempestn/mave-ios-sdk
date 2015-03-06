//
//  MAVECustomSharePageViewControllerTests.m
//  MaveSDK
//
//  Created by Danny Cosson on 1/9/15.
//
//

#import <UIKit/UIKit.h>
#import <Social/Social.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "MaveSDK.h"
#import "MAVEConstants.h"
#import "MAVEShareToken.h"
#import "MAVECustomSharePageViewController.h"
#import "MAVEInvitePageChooser.h"
#import "MAVEClientPropertyUtils.h"

@interface MaveSDK(Testing)
+ (void)resetSharedInstanceForTesting;
@end

@interface MAVECustomSharePageViewControllerTests : XCTestCase

@property (nonatomic, strong) MAVECustomSharePageViewController *viewController;
@property (nonatomic, strong) id viewControllerMock;
@property (nonatomic, strong) id sharerMock;
@property (nonatomic, strong) MAVERemoteConfiguration *remoteConfig;
@property (nonatomic, copy) NSString *applicationID;
@property (nonatomic, copy) NSString *shareToken;

@end

@implementation MAVECustomSharePageViewControllerTests

- (void)setUp {
    [super setUp];
    [MaveSDK resetSharedInstanceForTesting];
    self.applicationID = @"foo123";
    [MaveSDK setupSharedInstanceWithApplicationID:self.applicationID];
    self.viewController = nil;
    self.viewControllerMock = nil;
    self.sharerMock = nil;
    self.remoteConfig = nil;
    self.shareToken = nil;
}

- (void)tearDown {
    if (self.viewControllerMock) {
        [self.viewControllerMock stopMocking];
    }
    [super tearDown];
}

- (void)testViewDidLoadLogsInvitePageView {
    MAVECustomSharePageViewController *vc =
        [[MAVECustomSharePageViewController alloc] init];

    id apiMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    OCMExpect([apiMock trackInvitePageOpenForPageType:MAVEInvitePageTypeCustomShare]);

    [vc viewDidLoad];

    OCMVerifyAll(apiMock);
}

- (void)testDismissAfterShare {
    [MaveSDK sharedInstance].invitePageChooser = [[MAVEInvitePageChooser alloc] init];
    MAVECustomSharePageViewController *vc = [[MAVECustomSharePageViewController alloc] init];
    [MaveSDK sharedInstance].invitePageChooser.activeViewController = vc;

    id mock = OCMPartialMock([MaveSDK sharedInstance].invitePageChooser);
    OCMExpect([mock dismissOnSuccess:1]);
    [vc dismissAfterShare];
    OCMVerifyAll(mock);
}

# pragma mark - Share methods
// setup helper for some methods that want mocked data
- (void)setupPartialMockForClientShareTests {
    self.viewController = [[MAVECustomSharePageViewController alloc] init];
    self.viewController.sharerObject = [[MAVESharer alloc] init];
    self.remoteConfig = [[MAVERemoteConfiguration alloc] initWithDictionary:[MAVERemoteConfiguration defaultJSONData]];
    self.shareToken = @"foobarsharetoken";

    self.sharerMock = OCMPartialMock(self.viewController.sharerObject);
    self.viewControllerMock = OCMPartialMock(self.viewController);
    OCMStub([self.sharerMock remoteConfiguration]).andReturn(self.remoteConfig);
    OCMStub([self.sharerMock shareToken]).andReturn(self.shareToken);
}
- (void)testSetupMock {
    [self setupPartialMockForClientShareTests];
}

- (void)testClientSideSMSShareSent {
    MAVECustomSharePageViewController *vc = [[MAVECustomSharePageViewController alloc] init];
    id mock = OCMPartialMock(vc);
    id sharerMock = OCMClassMock([MAVESharer class]);
    OCMExpect([sharerMock composeClientSMSInviteToRecipientPhones:nil completionBlock:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completionBlock)(MessageComposeResult result) = obj;
        completionBlock(MessageComposeResultSent);
        return YES;
    }]]);
    OCMExpect([mock presentViewController:[OCMArg any] animated:YES completion:nil]);
    OCMExpect([mock dismissAfterShare]);

    [vc smsClientSideShare];

    OCMVerifyAll(mock);
    OCMVerifyAll(sharerMock);
}

- (void)testClientSideSMSShareCanceled {
    // On cancel, we don't dismiss the share page view controller
    MAVECustomSharePageViewController *vc = [[MAVECustomSharePageViewController alloc] init];
    id mock = OCMPartialMock(vc);
    id sharerMock = OCMClassMock([MAVESharer class]);
    OCMExpect([sharerMock composeClientSMSInviteToRecipientPhones:nil completionBlock:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completionBlock)(MessageComposeResult result) = obj;
        completionBlock(MessageComposeResultCancelled);
        return YES;
    }]]);
    OCMExpect([mock presentViewController:[OCMArg any] animated:YES completion:nil]);
    [[mock reject] dismissAfterShare];

    [vc smsClientSideShare];

    OCMVerifyAll(mock);
    OCMVerifyAll(sharerMock);
}

- (void)testClientSideSMSShareFailed {
    // Failed is same as cancel, the underlying helper displays the error alert
    MAVECustomSharePageViewController *vc = [[MAVECustomSharePageViewController alloc] init];
    id mock = OCMPartialMock(vc);
    id sharerMock = OCMClassMock([MAVESharer class]);
    OCMExpect([sharerMock composeClientSMSInviteToRecipientPhones:nil completionBlock:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completionBlock)(MessageComposeResult result) = obj;
        completionBlock(MessageComposeResultFailed);
        return YES;
    }]]);
    OCMExpect([mock presentViewController:[OCMArg any] animated:YES completion:nil]);
    [[mock reject] dismissAfterShare];

    [vc smsClientSideShare];

    OCMVerifyAll(mock);
    OCMVerifyAll(sharerMock);
}

- (void)testClientEmailShare {
    [self setupPartialMockForClientShareTests];
    NSString *expectedSubject = @"Join DemoApp";
    NSString *expectedBody = [NSString stringWithFormat:@"Hey, I've been using DemoApp and thought you might like it. Check it out:\n\n%@e/foobarsharetoken", MAVEShortLinkBaseURL];

    id mailComposerMock = OCMClassMock([MFMailComposeViewController class]);
    OCMExpect([self.viewControllerMock _createMailComposeViewController]).andReturn(mailComposerMock);

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    OCMExpect([apiInterfaceMock trackShareActionClickWithShareType:@"client_email"]);

    OCMExpect([self.viewControllerMock presentViewController:[OCMArg checkWithBlock:^BOOL(id obj) {
        MFMailComposeViewController *controller = obj;
        XCTAssertEqualObjects(controller, mailComposerMock);
        return YES;
    }] animated:YES completion:nil]);

    OCMExpect([mailComposerMock setMailComposeDelegate:self.viewController]);
    OCMExpect([mailComposerMock setSubject:expectedSubject]);
    OCMExpect([mailComposerMock setMessageBody:expectedBody isHTML:NO]);

    [self.viewController emailClientSideShare];

    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(mailComposerMock);
    OCMVerifyAll(apiInterfaceMock);
}

- (void)testClientEmailHandlerEmailSent {
    [self setupPartialMockForClientShareTests];

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    OCMExpect([self.viewControllerMock dismissAfterShare]);
    OCMExpect([self.viewControllerMock dismissViewControllerAnimated:YES completion:nil]);
    OCMExpect([apiInterfaceMock trackShareWithShareType:@"client_email" shareToken:[self.viewController.sharerObject shareToken] audience:nil]);

    [self.viewController mailComposeController:nil didFinishWithResult:MFMailComposeResultSent error:nil];

    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(apiInterfaceMock);
}

- (void)testClientEmailHandlerEmailNotSent {
    [self setupPartialMockForClientShareTests];

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    [[self.viewControllerMock reject] dismissAfterShare];
    OCMExpect([self.viewControllerMock dismissViewControllerAnimated:YES completion:nil]);
    [[apiInterfaceMock reject] trackShareWithShareType:@"client_email" shareToken:[self.viewController.sharerObject shareToken] audience:nil];

    [self.viewController mailComposeController:nil didFinishWithResult:MFMailComposeResultCancelled error:nil];

    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(apiInterfaceMock);
}

- (void)testFacebookiOSNativeShare {
    [self setupPartialMockForClientShareTests];
    NSString *expectedCopy = @"I love DemoApp. You should try it.";
    NSString *expectedURL = [NSString stringWithFormat:@"%@f/foobarsharetoken", MAVEShortLinkBaseURL];

    id fbVC = OCMClassMock([SLComposeViewController class]);
    OCMExpect([self.viewControllerMock _createFacebookComposeViewController]).andReturn(fbVC);

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    OCMExpect([apiInterfaceMock trackShareActionClickWithShareType:@"facebook"]);

    OCMExpect([self.viewControllerMock presentViewController:[OCMArg checkWithBlock:^BOOL(id obj) {
        SLComposeViewController *controller = obj;
        XCTAssertEqualObjects(controller, fbVC);
        return YES;
    }] animated:YES completion:nil]);

    OCMExpect([fbVC setCompletionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(SLComposeViewControllerResult result) = obj;
        completionBlock(SLComposeViewControllerResultDone);
        return YES;
    }]]);
    OCMExpect([fbVC setInitialText:expectedCopy]);
    OCMExpect([fbVC addURL:[NSURL URLWithString:expectedURL]]);

    OCMExpect([self.viewControllerMock facebookHandleShareResult:SLComposeViewControllerResultDone]);

    [self.viewController facebookiOSNativeShare];

    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(fbVC);
    OCMVerifyAll(apiInterfaceMock);
}

- (void)testFacebookHandleShareResultDone {
    [self setupPartialMockForClientShareTests];

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    OCMExpect([apiInterfaceMock trackShareWithShareType:@"facebook" shareToken:[self.viewController.sharerObject shareToken] audience:nil]);
    OCMExpect([self.viewControllerMock dismissAfterShare]);
    OCMExpect([self.viewControllerMock dismissViewControllerAnimated:YES completion:nil]);
    [self.viewControllerMock facebookHandleShareResult:SLComposeViewControllerResultDone];

    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(apiInterfaceMock);
}

- (void)testFacebookHandleShareResultCancelled {
    [self setupPartialMockForClientShareTests];

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    [[apiInterfaceMock reject] trackShareWithShareType:@"facebook" shareToken:[self.viewController.sharerObject shareToken] audience:nil];
    [[self.viewControllerMock reject] dismissAfterShare];
    OCMExpect([self.viewControllerMock dismissViewControllerAnimated:YES completion:nil]);
    [self.viewControllerMock facebookHandleShareResult:SLComposeViewControllerResultCancelled];

    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(apiInterfaceMock);
}

- (void)testTwitteriOSNativeShare {
    [self setupPartialMockForClientShareTests];
    NSString *expectedCopy = [NSString stringWithFormat:@"I love DemoApp. Try it out %@t/foobarsharetoken", MAVEShortLinkBaseURL];

    id twitterVC = OCMClassMock([SLComposeViewController class]);
    OCMExpect([self.viewControllerMock _createTwitterComposeViewController]).andReturn(twitterVC);

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    OCMExpect([apiInterfaceMock trackShareActionClickWithShareType:@"twitter"]);

    OCMExpect([self.viewControllerMock presentViewController:[OCMArg checkWithBlock:^BOOL(id obj) {
        SLComposeViewController *controller = obj;
        XCTAssertEqualObjects(controller, twitterVC);
        return YES;
    }] animated:YES completion:nil]);

    OCMExpect([twitterVC setCompletionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(SLComposeViewControllerResult result) = obj;
        completionBlock(SLComposeViewControllerResultDone);
        return YES;
    }]]);
    OCMExpect([twitterVC setInitialText:expectedCopy]);

    OCMExpect([self.viewControllerMock twitterHandleShareResult:SLComposeViewControllerResultDone]);

    [self.viewController twitteriOSNativeShare];

    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(twitterVC);
    OCMVerifyAll(apiInterfaceMock);
}

- (void)testTwitterHandleShareResultDone {
    [self setupPartialMockForClientShareTests];

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    OCMExpect([apiInterfaceMock trackShareWithShareType:@"twitter" shareToken:[self.viewController.sharerObject shareToken] audience:nil]);
    OCMExpect([self.viewControllerMock dismissAfterShare]);
    OCMExpect([self.viewControllerMock dismissViewControllerAnimated:YES completion:nil]);

    [self.viewControllerMock twitterHandleShareResult:SLComposeViewControllerResultDone];

    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(apiInterfaceMock);
}

- (void)testTwitterHandleShareResultCancelled {
    [self setupPartialMockForClientShareTests];

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    [[apiInterfaceMock reject] trackShareWithShareType:@"twitter" shareToken:[self.viewController.sharerObject shareToken] audience:nil];
    [[self.viewControllerMock reject] dismissAfterShare];
    OCMExpect([self.viewControllerMock dismissViewControllerAnimated:YES completion:nil]);

    [self.viewControllerMock twitterHandleShareResult:SLComposeViewControllerResultCancelled];

    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(apiInterfaceMock);
}

- (void)testClipboardShare {
    [self setupPartialMockForClientShareTests];
    NSString *expectedShareCopy = [NSString stringWithFormat:@"%@c/foobarsharetoken", MAVEShortLinkBaseURL];

// TODO: test taht remote config copy appended to link
//    MAVERemoteConfiguration *remoteConfig = [[MAVERemoteConfiguration alloc] init];
//    remoteConfig.clipboardShare = [[MAVERemoteConfigurationClipboardShare alloc] init];
//    remoteConfig.clipboardShare.text = @"Blah copy";
//
//    OCMExpect([self.viewControllerMock remoteConfiguration]).andReturn(remoteConfig);

    id pasteboardMock = OCMClassMock([UIPasteboard class]);
    OCMExpect([self.viewControllerMock _generalPasteboardForClipboardShare]).andReturn(pasteboardMock);
    // since any copy operation might get shared, reset the share token on copy to clipboard
    OCMExpect([self.sharerMock resetShareToken]);

    id apiInterfaceMock = OCMPartialMock([MaveSDK sharedInstance].APIInterface);
    OCMExpect([apiInterfaceMock trackShareActionClickWithShareType:@"clipboard"]);

    // TODO: test the uialert view

    OCMExpect([pasteboardMock setString:expectedShareCopy]);

    [self.viewController clipboardShare];

    OCMVerifyAll(pasteboardMock);
    OCMVerifyAll(self.viewControllerMock);
    OCMVerifyAll(self.sharerMock);
    OCMVerifyAll(apiInterfaceMock);
}

@end
