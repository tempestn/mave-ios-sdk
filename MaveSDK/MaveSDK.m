//
//  InvitePage.m
//  MaveSDKDevApp
//
//  Created by dannycosson on 9/25/14.
//  Copyright (c) 2015 Mave Technologies, Inc. All rights reserved.
//

#import "MaveSDK.h"
#import "MaveSDK_Internal.h"
#import "MAVEInvitePageViewController.h"
#import "MAVEConstants.h"
#import "MAVEIDUtils.h"
#import "MAVEDisplayOptions.h"
#import "MAVERemoteConfiguration.h"
#import "MAVEShareToken.h"
#import "MAVECustomSharePageViewController.h"
#import "MAVESuggestedInvites.h"
#import "MAVEABUtils.h"
#import "MAVEABPermissionPromptHandler.h"

@implementation MaveSDK {
    // Controller
    UINavigationController *invitePageNavController;

    // Properties with overwritten getters & setters
    MAVEUserData *_userData;
}

//
// Init and handling shared instance & needed data
//
- (instancetype)initCustom {
    if (self = [self init]) {
        _isInitialAppLaunch = ![MAVEIDUtils isAppDeviceIDStoredToDefaults];
        _appDeviceID = [MAVEIDUtils loadOrCreateNewAppDeviceID];

        _displayOptions = [[MAVEDisplayOptions alloc] initWithDefaults];
        NSString *apiBaseURL = [MAVEAPIBaseURL stringByAppendingString:MAVEAPIVersion];
        _APIInterface = [[MAVEAPIInterface alloc] initWithBaseURL:apiBaseURL];
        _addressBookSyncManager = [[MAVEABSyncManager alloc] init];
        _inviteSender = [[MAVEInviteSender alloc] init];
        _remoteConfiguration = [[MAVERemoteConfiguration alloc] initWithDictionary:[MAVERemoteConfiguration defaultJSONData]];
    }
    return self;
}

static MaveSDK *sharedInstance = nil;
static dispatch_once_t sharedInstanceonceToken;

+ (void)setupSharedInstance {
    dispatch_once(&sharedInstanceonceToken, ^{
        sharedInstance = [[self alloc] initCustom];

        sharedInstance.referringDataBuilder = [MAVEReferringData remoteBuilderNoPreFetch];
        [sharedInstance.APIInterface trackAppOpenFetchingReferringDataWithPromise:sharedInstance.referringDataBuilder.promise];

        sharedInstance.suggestedInvitesBuilder = [MAVESuggestedInvites remoteBuilder];


#ifndef UNIT_TESTING
        // sync contacts, but wait a few seconds so it doesn't compete with fetching our
        // share token or remote configuration.
        // Don't run this in unit tests because it interferes with the other tests.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [sharedInstance.addressBookSyncManager atLaunchSyncContactsAndPopulateSuggestedByPermissions];
        });
#endif
    });
}

// ability to reset singleton during tests
# if DEBUG
+ (void)resetSharedInstanceForTesting {
    sharedInstanceonceToken = 0;
}
#endif

+ (instancetype)sharedInstance {
    if (sharedInstance == nil) {
        MAVEErrorLog(@"You did not set up shared instance with app id");
    }
    return sharedInstance;
}

- (NSError *)validateUserSetup {
    NSInteger errCode = 0;
    NSString *humanError = @"";
    if (self.userData == nil) {
        humanError = @"identifyUser not called";
        errCode = MAVEValidationErrorUserIdentifyNeverCalledCode;
    } else if (self.userData.userID == nil) {
        humanError = @"userID set to nil";
        errCode = MAVEValidationErrorUserIDNotSetCode;
    } else if (self.userData.firstName == nil) {
        humanError = @"user firstName set to nil";
        errCode = MAVEValidationErrorUserNameNotSetCode;
    } else {
        return nil;
    }
    MAVEDebugLog(@"Error with MaveSDK sharedInstance user info setup - %@", humanError);
    return [[NSError alloc] initWithDomain:MAVE_VALIDATION_ERROR_DOMAIN
                                      code:errCode
                                  userInfo:@{@"message": humanError}];
}

- (BOOL)isSetupOK {
    return YES;
}


- (NSArray *)suggestedInvitesWithFullContactsList:(NSArray *)contacts delay:(CGFloat)seconds {
    // Pick randomly from the contacts list if debugging
    if (self.debug) {
        CGFloat debugDelay = MIN(self.debugSuggestedInvitesDelaySeconds, seconds);
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, debugDelay * NSEC_PER_SEC));
        NSMutableArray *debugSuggestions = [NSMutableArray arrayWithCapacity:self.debugNumberOfRandomSuggestedInvites];
        NSMutableArray *mutableContacts =[NSMutableArray arrayWithArray:contacts];
        NSInteger numToReturn = MIN(self.debugNumberOfRandomSuggestedInvites, [mutableContacts count]);
        for (NSInteger i = 0; i < numToReturn; i++) {
            NSUInteger index = arc4random() % [mutableContacts count];
            [debugSuggestions addObject:[mutableContacts objectAtIndex:index]];
            [mutableContacts removeObjectAtIndex:index];
        }
        return [NSArray arrayWithArray:debugSuggestions];
    }

    MAVESuggestedInvites *suggestedInvites = (MAVESuggestedInvites *)[self.suggestedInvitesBuilder createObjectSynchronousWithTimeout:seconds];
    // At this point we don't know when the suggestion objects were created, and bc of
    // how the contacts invite page is designed we need them to be instances of the
    // same objects displayed in the address book. So use the helper method to look
    // up the exact instances that we want by hashed record IDs.
    NSArray *suggestionsWrongInstances = suggestedInvites.suggestions;
    NSArray *suggestions = [MAVEABUtils instancesOfABPersonsInList:suggestionsWrongInstances fromAllContacts:contacts];
    for (MAVEABPerson *person in suggestions) {
        person.isSuggestedContact = YES;
    }
    return suggestions;
}


- (NSString *)defaultSMSMessageText {
    if (_defaultSMSMessageText) {
        return _defaultSMSMessageText;
    } else {
        return self.remoteConfiguration.serverSMS.text;
    }
}

- (NSString *)inviteExplanationCopy {
    NSString *serverCopy = self.remoteConfiguration.contactsInvitePage.explanationCopy;
    if (self.displayOptions.inviteExplanationCopy) {
        return self.displayOptions.inviteExplanationCopy;
    } else {
        return serverCopy;
    }
}

// Persist userData to disk, if app doesn't set it we can use the on-disk value
// that it set last time (if any)
- (MAVEUserData *)userData {
    if (!_userData) {
        @try {
            NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:MAVEUserDefaultsKeyUserData];
            if (data) {
                NSDictionary *userDataAttrs = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                if (userDataAttrs && [userDataAttrs count] > 0) {
                    _userData = [[MAVEUserData alloc] initWithDictionary:userDataAttrs];
                }
            }
        }
        @catch (NSException *exception) {
            _userData = nil;
        }
    }
    return _userData;
}

- (void)setUserData:(MAVEUserData *)userData {
    _userData = userData;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[userData toDictionary]];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:MAVEUserDefaultsKeyUserData];
}

//
// Methods to get data from our sdk
//
- (void)getReferringData:(void (^)(MAVEReferringData *))referringDataHandler {
    if (self.debug && referringDataHandler) {
        referringDataHandler(self.debugFakeReferringData);
        return;
    }
    [self.referringDataBuilder createObjectWithTimeout:4 completionBlock:^(id object) {
        referringDataHandler((MAVEReferringData *)object);
    }];
}

- (void)getSuggestedInvites:(void (^)(NSArray *))suggestedInvitesHandler {
    [self getSuggestedInvites:suggestedInvitesHandler timeout:10];
}

- (void)getSuggestedInvites:(void (^)(NSArray *))suggestedInvitesHandler
                    timeout:(CGFloat)timeout {
    if (![[MAVEABUtils addressBookPermissionStatus] isEqual:MAVEABPermissionStatusAllowed]) {
        suggestedInvitesHandler(nil);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        __block NSArray *contacts;
        // not actually going to prompt because we already have permission
        [MAVEABPermissionPromptHandler promptForContactsWithCompletionBlock:^(NSArray *_contacts) {
            contacts = _contacts;
            dispatch_semaphore_signal(sema);
        }];
        // not going to be long because we already have contacts permission
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

        suggestedInvitesHandler([self suggestedInvitesWithFullContactsList:contacts delay:timeout]);
    });
}

//
// Funnel events that need to be called explicitly by consumer
//
- (void)identifyUser:(MAVEUserData *)userData {
    self.userData = userData;
    NSError *validationError = [self validateUserSetup];
    if (validationError == nil) {
        [self.APIInterface identifyUser];
    }
}

- (void)identifyAnonymousUser {
    MAVEUserData *user = [[MAVEUserData alloc] initAutomaticallyFromDeviceName];
    if (user) {
        [self identifyUser:user];
    }
}

- (void)trackSignup {
    [self.APIInterface trackSignup];
}

//
// Methods for consumer to present/manage the invite page
//

- (void)presentInvitePageModallyWithBlock:(MAVEInvitePagePresentBlock)presentBlock
                             dismissBlock:(MAVEInvitePageDismissBlock)dismissBlock
                            inviteContext:(NSString *)inviteContext {
    if (![self isSetupOK]) {
        MAVEErrorLog(@"Not displaying Mave invite page because parameters not all set, see other log errors");
        return;
    }
    self.invitePageChooser = [[MAVEInvitePageChooser alloc]
                              initForModalPresentWithCancelBlock:dismissBlock];
    [self.invitePageChooser chooseAndCreateInvitePageViewController];
    [self.invitePageChooser setupNavigationBarForActiveViewController];
    self.inviteContext = inviteContext;

    // present the navigation controller if it's wrapped in one, otherwise just
    // the active view controller
    UIViewController *vcToPresent = self.invitePageChooser.activeViewController;
    if (vcToPresent.navigationController) {
        vcToPresent = vcToPresent.navigationController;
    }
    presentBlock(vcToPresent);
}

- (void)presentInvitePagePushWithBlock:(MAVEInvitePagePresentBlock)presentBlock
                          forwardBlock:(MAVEInvitePageDismissBlock)forwardBlock
                            backBlock:(MAVEInvitePageDismissBlock)backBlock
                         inviteContext:(NSString *)inviteContext {
    if (![self isSetupOK]) {
        MAVEErrorLog(@"Not displaying Mave invite page because parameters not all set, see other log errors");
        return;
    }
    self.invitePageChooser = [[MAVEInvitePageChooser alloc]
                              initForPushPresentWithForwardBlock:forwardBlock
                              backBlock:backBlock];
    [self.invitePageChooser chooseAndCreateInvitePageViewController];
    [self.invitePageChooser setupNavigationBarForActiveViewController];
    self.inviteContext = inviteContext;
    presentBlock(self.invitePageChooser.activeViewController);
}

//
// Programatic SMS invites
//
- (void)sendSMSInviteMessage:(NSString *)message
                toRecipients:(NSArray *)recipientPhoneNumbers
           additionalOptions:(NSDictionary *)options
                  errorBlock:(void (^)(NSError *error))errorBlock {
    NSError *userSetupError = [self validateUserSetup];
    if (userSetupError) {
        if (errorBlock) {
            errorBlock(userSetupError);
        }
        return;
    }

    // options
    NSString *inviteContext = [options objectForKey:@"invite_context"];
    if (!inviteContext || (id)inviteContext == [NSNull null]) {
        inviteContext = @"programatic invite";
    }
    self.inviteContext = inviteContext;
    NSString *linkDestinationURL = [options objectForKey:@"link_destination_url"];
    NSDictionary *customData = [options objectForKey:@"custom_referring_data"];
    if (customData && ![NSJSONSerialization isValidJSONObject:customData]) {
        customData = nil;
        if (errorBlock) {
            NSError *error = [NSError errorWithDomain:MAVE_VALIDATION_ERROR_DOMAIN code:0 userInfo:@{@"message": @"custom_referring_data parameter can't be serialized as JSON"}];
            errorBlock(error);
        }
        return;
    }

    [self.APIInterface sendInvitesWithRecipientPhoneNumbers:recipientPhoneNumbers
                                    recipientContactRecords:nil
                                                    message:message
                                                     userId:self.userData.userID
                                   inviteLinkDestinationURL:linkDestinationURL
                                             wrapInviteLink:self.userData.wrapInviteLink
                                                 customData:customData
                                            completionBlock:^(NSError *error, NSDictionary *responseData) {
                                  if (error && errorBlock) {
                                      NSError *returnError = [[NSError alloc] initWithDomain:error.domain code:error.code userInfo:@{@"message": @"Error making request to send SMS invites"}];
                                      errorBlock(returnError);
                                  } else {
                                      MAVEInfoLog(@"Sent %lu SMS invites", [recipientPhoneNumbers count]);
                                  }
                              }];
}

#pragma mark - Debug/ testing properties
- (void)setDebug:(BOOL)debug {
    if (debug) {
        MAVEErrorLog(@"MAVE IS SET TO DEBUG MODE, MAKE SURE TO DISABLE IT BEFORE RELEASING");
    }
    _debug = debug;
}

+(MAVEReferringData *)generateFakeReferringDataForTestingWithCustomData:(NSDictionary *)customData {
    MAVEReferringData *rd = [[MAVEReferringData alloc] init];
    rd.currentUser = [[MAVEUserData alloc] init];
    rd.currentUser.phone = @"+12125559999";
    rd.referringUser = [[MAVEUserData alloc] initWithUserID:@"100" firstName:@"Danny" lastName:@"Example" email:@"danny@example.com" phone:@"+18085551111"];
    rd.referringUser.picture = [NSURL URLWithString:@"http://mave.io/images/giraffe-face.jpg"];
    rd.customData = customData;
    return rd;
}


@end
