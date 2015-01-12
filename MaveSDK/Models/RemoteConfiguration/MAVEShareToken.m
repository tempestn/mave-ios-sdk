//
//  MAVEShareToken.m
//  MaveSDK
//
//  Created by Danny Cosson on 1/7/15.
//
//

#import "MAVEShareToken.h"
#import "MaveSDK.h"
#import "MAVEConstants.h"

#ifdef UNITTESTING
NSString * const MAVEUserDefaultsKeyShareToken = @"MAVETESTSUserDefaultsKeyShareToken";
#else
NSString * const MAVEUserDefaultsKeyShareToken = @"MAVEUserDefaultsKeyShareToken";
#endif

NSString * const MAVEShareTokenKeyShareToken = @"share_token";

@implementation MAVEShareToken

- (instancetype)initWithDictionary:(NSDictionary *)data {
    if (self = [super init]) {
        self.shareToken = [data objectForKey:@"share_token"];
        // nil is different than empty string
        if (self.shareToken == nil) {
            return nil;
        }
        NSLog(@"Using share token %@", self.shareToken);
    }
    return self;
}

+ (MAVERemoteObjectBuilder *)remoteBuilder {
    return [[MAVERemoteObjectBuilder alloc] initWithClassToCreate:[self class]
            preFetchBlock:^(MAVEPromise *promise) {
                [[MaveSDK sharedInstance].APIInterface
                getNewShareTokenWithCompletionBlock:^(NSError *error, NSDictionary *responseData) {
                    if (error) {
                        [promise rejectPromise];
                    } else {
                        DebugLog(@"Using a new share token from server");
                        [promise fulfillPromise:(NSValue *)responseData];
                    }
                }];
            } defaultData:[self defaultJSONData]
            saveIfSuccessfulToUserDefaultsKey:MAVEUserDefaultsKeyShareToken
                                           preferLocallySavedData:YES];
}

+ (NSDictionary *)defaultJSONData {
    return @{
        MAVEShareTokenKeyShareToken: @"",
    };
}

+ (void)clearUserDefaults {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MAVEUserDefaultsKeyShareToken];
}

@end
