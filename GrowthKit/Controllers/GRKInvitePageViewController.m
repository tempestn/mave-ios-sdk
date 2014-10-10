//
//  InvitePageViewController.m
//  GrowthKitDevApp
//
//  Created by dannycosson on 10/1/14.
//  Copyright (c) 2014 Growthkit Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GrowthKit.h"
#import "GRKInvitePageViewController.h"
#import "GRKABTableViewController.h"
#import "GRKInviteMessageViewController.h"

@interface GRKInvitePageViewController ()

@end

@implementation GRKInvitePageViewController {
    GRKABTableViewController *abTableViewDelegate;
    GRKInviteMessageViewController *inviteMessageViewDelegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"Invite Page viewDidLoad");
    // Do any additional setup after loading the view.

    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self
                      selector:@selector(keyboardWillShow:)
                          name:UIKeyboardWillShowNotification
                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(deviceWillRotate:)
                          name:UIDeviceOrientationDidChangeNotification
                        object:nil];
}

- (void)loadView {
    [super loadView];
    NSLog(@"Invite Page loadView!");
    [self setupNavgationBar];
    self.view = [self createContainerAndChildViews];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)keyboardWillShow:(NSNotification *)notification {
    CGSize kbSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    [self setContainerAndChildFramesWithKeyboardSize:kbSize];
}

- (void)deviceWillRotate:(NSNotification *)notification {
    [self setContainerAndChildFramesWithKeyboardSize:CGSizeMake(0, 0)];
}


- (void)cleanupForDismiss {
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter removeObserver:self
                             name:UIKeyboardWillShowNotification
                           object:nil];
    [defaultCenter removeObserver:self
                             name:UIDeviceOrientationDidChangeNotification
                           object:nil];
}

+ (void)computeChildFramesWithKeyboardSize:(CGSize)kbSize
                      createContainerFrame:(CGRect *)containerFrame
                            tableViewFrame:(CGRect *)tableViewFrame
                    inviteMessageViewFrame:(CGRect *)inviteMessageViewFrame {
    CGSize appFrameSize = [[UIScreen mainScreen] applicationFrame].size;

    float extraVerticalPadding = 0;
    if (![UIApplication sharedApplication].statusBarHidden) {
        // 20 is to account for the top menu bar which always overlays your app in ios7+
        extraVerticalPadding = 20;
    }

    float inviteViewHeight = 70;
    float tableViewHeight = appFrameSize.height - inviteViewHeight - kbSize.height + extraVerticalPadding;
    
    // Set pointers to return multi
    *containerFrame = CGRectMake(0, 0, appFrameSize.width, appFrameSize.height);
    *tableViewFrame = CGRectMake(0, 0, appFrameSize.width, tableViewHeight);
    *inviteMessageViewFrame = CGRectMake(0, tableViewHeight, appFrameSize.width, inviteViewHeight);
}

- (UIView *)createContainerAndChildViews {
    CGRect cvf, tvf, imvf;
    [[self class]computeChildFramesWithKeyboardSize:CGSizeMake(0, 0)
                               createContainerFrame:&cvf
                                     tableViewFrame:&tvf
                             inviteMessageViewFrame:&imvf];
    UIView *containerView = [[UIView alloc] initWithFrame:cvf];

    abTableViewDelegate = [[GRKABTableViewController alloc] initAndCreateTableViewWithFrame:tvf];
    inviteMessageViewDelegate = [[GRKInviteMessageViewController alloc] initAndCreateViewWithFrame:imvf
            delegate:self selectedPhones:abTableViewDelegate.selectedPhoneNumbers];
    [containerView addSubview:abTableViewDelegate.tableView];
    [containerView addSubview:inviteMessageViewDelegate.view];
    
    return containerView;
}

- (void)setContainerAndChildFramesWithKeyboardSize:(CGSize)kbSize {
    CGRect cvf, tvf, imvf;
    [[self class]computeChildFramesWithKeyboardSize:kbSize
                               createContainerFrame:&cvf
                                     tableViewFrame:&tvf
                             inviteMessageViewFrame:&imvf];
    [self.view setFrame:cvf];
    [abTableViewDelegate.tableView setFrame:tvf];
    [inviteMessageViewDelegate.view setFrame:imvf];
}

- (void)setupNavgationBar {
    self.navigationItem.title = @"Invite Friends";
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc]
                                     initWithTitle:@"Cancel"
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(dismissAfterCancel:)];
    [self.navigationItem setLeftBarButtonItem:cancelButton];
}

- (void)dismissAfterCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self cleanupForDismiss];
}

@end