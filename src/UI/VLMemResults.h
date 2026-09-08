/**
 * VansonLoader L2.3 - VLMemResults
 * 内存搜索结果独立窗口
 * 支持拖动、缩小、避开灵动岛
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLMemResults : NSObject
+ (void)show;
+ (void)showMinimized;  // 直接显示为悬浮图标
+ (void)hide;
+ (void)toggle;
+ (BOOL)isVisible;
+ (void)reloadData;
+ (void)notifyResultsUpdated;  // 搜索完成后调用
@end

NS_ASSUME_NONNULL_END
