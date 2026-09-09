/**
 * VansonLoader L2.3 - 悬浮按钮
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLFloatingButton : UIButton

+ (instancetype)sharedButton;
+ (void)installIfNeeded;          // 新增
+ (UIImage *)iconImage;

@end

// 兼容别名
typedef VLFloatingButton VFloatingButton;

NS_ASSUME_NONNULL_END
