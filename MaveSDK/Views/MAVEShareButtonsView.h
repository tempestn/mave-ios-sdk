//
//  MAVEShareIconsView.h
//  MaveSDK
//
//  Created by Danny Cosson on 3/26/15.
//
//

#import <UIKit/UIKit.h>

@protocol MAVEShareButtonsDelegate

- (void)smsClientSideShare;
- (void)emailClientSideShare;
- (void)facebookiOSNativeShare;
- (void)twitteriOSNativeShare;
- (void)clipboardShare;

@end

@interface MAVEShareButtonsView : UIView

@property (nonatomic, strong) id<MAVEShareButtonsDelegate>delegate;
@property (nonatomic, strong) NSMutableArray *shareButtons;

@property (nonatomic, strong) UIColor *iconColor;
@property (nonatomic, strong) UIColor *iconTextColor;
@property (nonatomic, strong) UIFont *iconFont;
@property (nonatomic, assign) BOOL useSmallIcons;

@property (nonatomic, assign) BOOL allowSMSShare;

- (instancetype)initWithDelegate:(id<MAVEShareButtonsDelegate>)delegate
                       iconColor:(UIColor *)iconColor
                        iconFont:(UIFont *)iconFont
                 backgroundColor:(UIColor *)backgroundColor
                   useSmallIcons:(BOOL)useSmallIcons
                   allowSMSShare:(BOOL)allowSMSShare;

// Helpers
- (CGSize)shareButtonSize;  // all share buttons should be the same size
- (UIButton *)genericShareButtonWithIconNamed:(NSString *)imageName
                                 andLabelText:(NSString *)text;

- (UIButton *)smsShareButton;
- (UIButton *)emailShareButton;
- (UIButton *)facebookShareButton;
- (UIButton *)twitterShareButton;
- (UIButton *)clipboardShareButton;

@end