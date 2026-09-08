/**
 * VansonLoader - VLPanel Internal Header (精简版)
 * 仅保留内存扫描/修改相关接口
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

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

extern BOOL g_touchPassthroughMode;
extern VMemDataType g_currentType;

// 主Tab索引（仅内存）
typedef NS_ENUM(NSInteger, VLMainTab) {
    VLMainTabMemory = 0
};

// 面板内部内存结果项
@interface VLPanelMemItem : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) VMemDataType dataType;
@property (nonatomic, copy) NSString *currentValue;
@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, copy) NSString *lockValue;
@end

// 前向声明
@class VPanelImpl;

// 常量
extern VPanelImpl *g_panel;
static const NSInteger kPageSize = 50;

@interface VPanelImpl : UIView <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

// 核心视图
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

// 内存页
@property (nonatomic, strong) UIView *pageMemory;
@property (nonatomic, strong) UISegmentedControl *memModeSeg;
@property (nonatomic, strong) UISegmentedControl *memTypeSeg;
@property (nonatomic, strong) UISegmentedControl *memTypeSeg2;
@property (nonatomic, strong) UITextField *memValueField;
@property (nonatomic, strong) UITextField *memValueField2; // for between/group if kept
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

// 保留部分属性避免大量改动编译错误（未使用页面设为 nil）
@property (nonatomic, strong) UIView *pageToolbox;
@property (nonatomic, strong) UIView *pageTools;
@property (nonatomic, strong) UIView *pageAbout;
@property (nonatomic, strong) UITableView *tbTable;
@property (nonatomic, strong) UIView *browserFusionView;
@property (nonatomic, strong) UIView *watchFusionView;
@property (nonatomic, assign) NSInteger currentSubTab;

- (void)setupPanel;
- (void)setupNavBar:(CGFloat)w;
- (void)setupMemoryPage:(CGFloat)w;
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
- (void)resetFusionViews;
- (UIView *)createBox:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w;
- (UIButton *)createSmallBtn:(NSString *)title frame:(CGRect)frame;
- (void)styleSegment:(UISegmentedControl *)seg;
- (void)addDoneButtonTo:(UITextField *)field;
- (void)stopBrowserRefreshTimer;

// Memory methods
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

@end

