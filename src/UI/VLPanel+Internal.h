/**
 * VansonLoader - VLPanel Internal Header (精简版)
 * 仅保留内存扫描/修改相关接口
 * 方法声明拆到 Category，避免 -Wincomplete-implementation
 */

#import <UIKit/UIKit.h>
#import "../Engine/VLMemEngine.h"
#import "../Utils/VLLocalization.h"
#import "../Utils/VLIconManager.h"
#import "VLMemoryBrowser.h"
#import "VLFloatingButton.h"
#import "VLMemResults.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>

#ifndef VERSION_STRING
#define VERSION_STRING @"unknown"
#endif

// 主题色
static inline UIColor *VLAccentColor(void) {
    return [UIColor colorWithRed:0.18 green:0.96 blue:0.86 alpha:1.0];
}

static inline UIColor *VLSecondaryAccentColor(void) {
    return [UIColor colorWithRed:0.56 green:0.38 blue:1.00 alpha:1.0];
}

static inline UIColor *VLPanelBackgroundColor(void) {
    return [UIColor colorWithRed:0.040 green:0.043 blue:0.060 alpha:0.97];
}

static inline UIColor *VLSurfaceColor(void) {
    return [UIColor colorWithRed:0.075 green:0.080 blue:0.105 alpha:0.92];
}

static inline UIColor *VLStrokeColor(void) {
    return [VLAccentColor() colorWithAlphaComponent:0.22];
}

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

extern BOOL g_touchPassthroughMode;
extern VMemDataType g_currentType;

typedef NS_ENUM(NSInteger, VLMainTab) {
    VLMainTabMemory = 0
};

@interface VLPanelMemItem : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) VMemDataType dataType;
@property (nonatomic, copy) NSString *currentValue;
@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, copy) NSString *lockValue;
@end

@class VPanelImpl;
extern VPanelImpl *g_panel;
static const NSInteger kPageSize = 50;

// 主类：只保留属性 + 主文件里真正实现的方法
@interface VPanelImpl : UIView <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) UIView *navBar;
@property (nonatomic, strong) UIScrollView *panelBody;
@property (nonatomic, strong) NSArray<UIButton *> *navTabButtons;
@property (nonatomic, strong) NSArray<UIButton *> *sizeButtons;
@property (nonatomic, assign) NSInteger currentSize;
@property (nonatomic, assign) VLMainTab currentTab;
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) CGPoint bgStartCenter;
@property (nonatomic, assign) CGFloat portraitBaseScale;

@property (nonatomic, strong) UIView *pageMemory;
@property (nonatomic, strong) UISegmentedControl *memModeSeg;
@property (nonatomic, strong) UISegmentedControl *memTypeSeg;
@property (nonatomic, strong) UISegmentedControl *memTypeSeg2;
@property (nonatomic, strong) UITextField *memValueField;
@property (nonatomic, strong) UITextField *memValueField2;
@property (nonatomic, strong) UILabel *memConsoleLabel;
@property (nonatomic, strong) UITableView *memResultsTable;
@property (nonatomic, strong) UILabel *memResultsCountLabel;
@property (nonatomic, strong) UILabel *memPageLabel;
@property (nonatomic, strong) UIButton *memSelectButton;
@property (nonatomic, strong) NSMutableArray<VLPanelMemItem *> *memResults;
@property (nonatomic, assign) NSInteger memCurrentPage;
@property (nonatomic, assign) BOOL memSelectMode;
@property (nonatomic, strong) NSMutableSet *memSelectedIndexes;
@property (nonatomic, strong) NSTimer *memLockTimer;
@property (nonatomic, strong) NSTimer *browserLockTimer;
@property (nonatomic, strong) NSTimer *browserRefreshTimer;
@property (nonatomic, strong) NSTimer *lockTimer;

@property (nonatomic, strong) UIView *pageToolbox;
@property (nonatomic, strong) UIView *pageTools;
@property (nonatomic, strong) UIView *pageAbout;
@property (nonatomic, strong) UITableView *tbTable;
@property (nonatomic, strong) UIView *browserFusionView;
@property (nonatomic, strong) UIView *watchFusionView;
@property (nonatomic, assign) NSInteger currentSubTab;

- (void)setupPanel;
- (UIView *)createBox:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w;
- (UIButton *)createSmallBtn:(NSString *)title frame:(CGRect)frame;
- (void)styleSegment:(UISegmentedControl *)seg;
- (void)addDoneButtonTo:(UITextField *)field;
- (void)resetFusionViews;
- (void)stopBrowserRefreshTimer;

@end

// Nav category（实现在 VLPanelNav.m）
@interface VPanelImpl (Nav)
- (void)setupNavBar:(CGFloat)w;
- (void)switchToTab:(VLMainTab)tab animated:(BOOL)animated;
- (void)updateNavTabHighlight;
- (void)updateSizeHighlight;
- (void)updateContentSize;
- (void)showWithAnimation;
- (void)hideWithAnimation;
- (void)close;
- (void)setFocused:(BOOL)focused animated:(BOOL)animated;
- (void)onDimTap;
- (void)onOrientationChanged;
@end

// Memory category（实现在 VLPanelMemory.m）
@interface VPanelImpl (Memory)
- (void)setupMemoryPage:(CGFloat)w;
- (void)memModeChanged;
- (void)updateMemUIForMode;
- (void)memTypeChanged:(UISegmentedControl *)seg;
- (void)memType2Changed:(UISegmentedControl *)seg;
- (void)doMemorySearch;
- (void)doMemoryFilter;
- (void)memPrevPage;
- (void)memNextPage;
- (void)handleMemResultLongPress:(UILongPressGestureRecognizer *)gr;
- (void)onMemFuzzySelected:(id)sender;
- (void)onTest1Tapped;
- (void)onTest2Tapped;          // 测试二
- (void)updateMemLocks;
@end
