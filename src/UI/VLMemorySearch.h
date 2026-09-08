/**
 * VansonLoader L2.3 - Memory Search UI
 * 内存搜索界面 (赛博朋克风格)
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLMemorySearch : NSObject

+ (void)setupMemoryView:(UIScrollView *)container panel:(id)panel;

@end

// 内存搜索视图控制器 (单例，保持状态)
@interface VLMemorySearchVC : UIViewController

+ (instancetype)shared;
+ (void)showFromWindow:(UIWindow *)window;
+ (void)showMinimized;  // 直接显示为悬浮图标
+ (void)toggle;
+ (void)hide;
+ (BOOL)isVisible;
- (void)minimize;

@end

// 兼容别名
typedef VLMemorySearch VMemorySearch;
typedef VLMemorySearchVC VMemorySearchVC;

NS_ASSUME_NONNULL_END
