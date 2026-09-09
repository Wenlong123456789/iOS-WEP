/**
 * VansonLoader - VLPanel 精简版
 * 仅保留内存扫描/修改 + 面板生命周期
 */

#import "VLPanel.h"
#import "VLPanel+Internal.h"
#import "VLPanelSizeHelper.h"
#import <stdlib.h>

// ═══ 全局实例 ═══
VPanelImpl *g_panel = nil;
BOOL g_touchPassthroughMode = NO;
VMemDataType g_currentType = VMemDataTypeI32;

@implementation VLPanelMemItem
@end

@implementation VPanelImpl

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.isFocused = YES;
        self.currentTab = VLMainTabMemory;
        self.currentSize = 2;
        self.memCurrentPage = 0;
        self.memSelectMode = NO;
        self.memSelectedIndexes = [NSMutableSet set];
        self.memResults = [NSMutableArray array];

        if (!g_currentType) g_currentType = VMemDataTypeI32;

        [[VMemEngine shared] initialize];
        [self setupPanel];

        self.memLockTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                             target:self
                                                           selector:@selector(updateMemLocks)
                                                           userInfo:nil
                                                            repeats:YES];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLanguageChanged) name:@"VansonLanguageChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMemResultsReceived:) name:@"VMemResultsToPanel" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMemItemLocked:) name:@"VMemItemLockedToPanel" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMemItemUnlocked:) name:@"VMemItemUnlockedFromPanel" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onOrientationChanged) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_memLockTimer invalidate];
    [_browserLockTimer invalidate];
    [_browserRefreshTimer invalidate];
    [_lockTimer invalidate];
}

#pragma mark - Panel Setup

- (void)setupPanel {
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    CGFloat longSide = MAX(sw, sh);
    CGFloat shortSide = MIN(sw, sh);
    CGFloat w = MIN(longSide * 0.94, 560);
    CGFloat maxH = shortSide * 0.85;

    if (sw < sh) {
        _portraitBaseScale = (sw * 0.94) / w;
        if (_portraitBaseScale > 1.0) _portraitBaseScale = 1.0;
    } else {
        _portraitBaseScale = 1.0;
    }

    _dimView = [[UIView alloc] initWithFrame:self.bounds];
    _dimView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.38];
    _dimView.alpha = 0;
    UITapGestureRecognizer *dimTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDimTap)];
    [_dimView addGestureRecognizer:dimTap];
    [self addSubview:_dimView];

    _bgView = [[UIView alloc] initWithFrame:CGRectMake((sw - w) / 2, (sh - maxH) / 2, w, maxH)];
    _bgView.backgroundColor = VLPanelBackgroundColor();
    _bgView.layer.cornerRadius = 18;
    _bgView.layer.borderWidth = 1.5;
    _bgView.layer.borderColor = VLStrokeColor().CGColor;
    _bgView.layer.shadowColor = VLAccentColor().CGColor;
    _bgView.layer.shadowOffset = CGSizeZero;
    _bgView.layer.shadowRadius = 28;
    _bgView.layer.shadowOpacity = 0.24;
    _bgView.clipsToBounds = YES;
    [self addSubview:_bgView];

    [self setupNavBar:w];

    CGFloat bodyTop = 44;
    _panelBody = [[UIScrollView alloc] initWithFrame:CGRectMake(0, bodyTop, w, maxH - bodyTop)];
    _panelBody.showsVerticalScrollIndicator = NO;
    _panelBody.showsHorizontalScrollIndicator = NO;
    _panelBody.bounces = YES;
    [_bgView addSubview:_panelBody];

    [self setupMemoryPage:w];
    [self switchToTab:VLMainTabMemory animated:NO];
}

#pragma mark - Helpers

- (UIView *)createBox:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, 100)];
    box.backgroundColor = VLSurfaceColor();
    box.layer.cornerRadius = 10;
    box.layer.borderWidth = 1;
    box.layer.borderColor = [VLStrokeColor() colorWithAlphaComponent:0.5].CGColor;

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, w - 16, 16)];
    t.text = title;
    t.textColor = VLAccentColor();
    t.font = [UIFont boldSystemFontOfSize:10];
    [box addSubview:t];
    return box;
}

- (UIButton *)createSmallBtn:(NSString *)title frame:(CGRect)frame {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:VLAccentColor() forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    btn.backgroundColor = [VLAccentColor() colorWithAlphaComponent:0.08];
    btn.layer.cornerRadius = 6;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [VLAccentColor() colorWithAlphaComponent:0.25].CGColor;
    return btn;
}

- (void)styleSegment:(UISegmentedControl *)seg {
    seg.backgroundColor = [VLSurfaceColor() colorWithAlphaComponent:0.8];
    if (@available(iOS 13.0, *)) {
        seg.selectedSegmentTintColor = [VLAccentColor() colorWithAlphaComponent:0.35];
    }
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [[UIColor cyanColor] colorWithAlphaComponent:0.7], NSFontAttributeName: [UIFont systemFontOfSize:10]} forState:UIControlStateNormal];
    [seg setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:10]} forState:UIControlStateSelected];
}

- (void)addDoneButtonTo:(UITextField *)field {
    UIToolbar *tb = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 40)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:field action:@selector(resignFirstResponder)];
    tb.items = @[flex, done];
    field.inputAccessoryView = tb;
}

- (void)resetFusionViews {
    // no-op in slim version
}

- (void)stopBrowserRefreshTimer {
    [_browserRefreshTimer invalidate];
    _browserRefreshTimer = nil;
}

#pragma mark - Notifications / Timers (stubs + memory)

- (void)onLanguageChanged {
    // 简单刷新：重建内存页
    if (self.pageMemory && self.bgView) {
        CGFloat w = self.bgView.frame.size.width;
        for (UIView *v in self.panelBody.subviews) [v removeFromSuperview];
        [self setupMemoryPage:w];
        [self switchToTab:VLMainTabMemory animated:NO];
    }
}

- (void)onMemResultsReceived:(NSNotification *)note {
    // 由 VLPanelMemory 处理
}

- (void)onMemItemLocked:(NSNotification *)note {}
- (void)onMemItemUnlocked:(NSNotification *)note {}

#pragma mark - TableView (memory only)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView.tag == 2001) {
        NSInteger total = self.memResults.count;
        NSInteger start = self.memCurrentPage * kPageSize;
        return MIN(kPageSize, MAX(0, total - start));
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"MemCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor cyanColor];
        cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:11];
        cell.detailTextLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.6];
        cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:9];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSInteger idx = self.memCurrentPage * kPageSize + indexPath.row;
    if (idx < (NSInteger)self.memResults.count) {
        VLPanelMemItem *item = self.memResults[idx];
        cell.textLabel.text = [NSString stringWithFormat:@"0x%llX", item.address];
        cell.detailTextLabel.text = item.currentValue ?: @"";
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // 编辑逻辑在 Memory category
}

@end

@implementation VLPanel

#pragma mark - Public API

+ (void)attachPanelToCurrentWindowIfNeeded {
    if (!g_panel) return;
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    if (g_panel.superview != w) {
        [g_panel removeFromSuperview];
        g_panel.frame = w.bounds;
        [w addSubview:g_panel];
    } else if (!CGRectEqualToRect(g_panel.frame, w.bounds)) {
        g_panel.frame = w.bounds;
    }
}

+ (void)initializeIfNeeded {
    if (g_panel) {
        [self attachPanelToCurrentWindowIfNeeded];
        return;
    }
    UIWindow *w = GetSafeWindow();
    if (!w) return;

    g_panel = [[VPanelImpl alloc] initWithFrame:w.bounds];
    g_panel.hidden = YES;
    [w addSubview:g_panel];
}

+ (void)show {
    if (!g_panel) [self initializeIfNeeded];
    if (!g_panel) return;
    [self attachPanelToCurrentWindowIfNeeded];
    [g_panel.superview bringSubviewToFront:g_panel];
    [g_panel showWithAnimation];
}

+ (void)hide {
    if (g_panel) [g_panel hideWithAnimation];
}

+ (void)toggle {
    if (!g_panel) { [self show]; return; }
    if (g_panel.hidden) [self show]; else [self hide];
}

+ (void)reloadList {
    if (g_panel) {
        [g_panel.memResultsTable reloadData];
    }
}

+ (void)updateTabsVisibility {
    // no-op
}

@end
