/**
 * VansonLoader L2.3 - VLWindowSwitches
 * 窗口开关管理页面
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 窗口关闭通知
extern NSString * const VLWindowDidCloseNotification;

@interface VLWindowSwitches : NSObject

/// 设置窗口开关页面
+ (void)setupWindowSwitchesView:(UIScrollView *)container;

/// 恢复之前打开的窗口状态
+ (void)restoreWindowStates;

@end

NS_ASSUME_NONNULL_END
