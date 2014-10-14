//
//  GRKHTTPManager.h
//  GrowthKitDevApp
//
//  Created by dannycosson on 10/8/14.
//  Copyright (c) 2014 Growthkit Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^GRKHTTPCompletionBlock)(NSInteger statusCode, NSDictionary *responseData);

@interface GRKHTTPManager : NSObject <NSURLSessionDelegate>

@property (nonatomic, readonly) NSString *applicationId;
@property (nonatomic, readonly) NSString *baseURL;
@property (nonatomic) NSURLSession *session;

- (GRKHTTPManager *)initWithApplicationId:(NSString *)applicationId;

// Specific Requests the app will make
- (void)sendInvitesWithPersons:(NSArray *)persons
                       message:(NSString *)messageText
               completionBlock:(GRKHTTPCompletionBlock)completionBlock;

@end