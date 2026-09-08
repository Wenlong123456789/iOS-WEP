/**
 * VansonLoader L2.7 - 统一主面板
 * PC风格导航栏 + 4个主Tab + 内嵌所有功能
 * 赛博朋克风格 UI
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLPanel : NSObject

+ (void)initializeIfNeeded;
+ (void)show;
+ (void)hide;
+ (void)toggle;
+ (void)reloadList;
+ (void)updateTabsVisibility;

@end

// 兼容别名
typedef VLPanel VPanel;

NS_ASSUME_NONNULL_END
