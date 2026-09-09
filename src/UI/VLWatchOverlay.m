/**
 * VansonLoader L2.3 - Watchpoint Overlay Implementation
 */

#import "VLWatchOverlay.h"
#import "VLDockBadge.h"
#import "VLPanelSizeHelper.h"
#import "../Engine/VLDebugEngine.h"
#import "../Engine/VLModEngine.h"
#import "../Utils/VLLocalization.h"
#import "../Utils/VLIconManager.h"
#import "../Models/VLModItem.h"
#import <objc/runtime.h>

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

extern NSMutableArray<VLModItem *> *g_rvaItems;
extern BOOL g_touchPassthroughMode;

#pragma mark - Container View

@interface VLWatchContainerView : UIView
@property (nonatomic, weak) UIView *contentView;
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) CGPoint dragStart;
@property (nonatomic, assign) CGPoint contentStart;
@property (nonatomic, strong) VLDockBadge *dockBadge;
- (void)minimize;
- (void)restore;
@end

@implementation VLWatchContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _isFocused = YES;
        _dockBadge = [[VLDockBadge alloc] initWithImage:IC(@"watchpoint") fallbackIcon:@"W"];
        _dockBadge.hidden = YES;
        __weak typeof(self) ws = self;
        _dockBadge.onTap = ^{ [ws restore]; };
        [self addSubview:_dockBadge];
    }
    return self;
}

- (void)minimize {
    if (!_contentView) return;
    [UIView animateWithDuration:0.3 animations:^{
        self.contentView.alpha = 0;
        self.contentView.transform = CGAffineTransformMakeScale(0.5, 0.5);
        self.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL f) {
        self.contentView.hidden = YES;
        [self->_dockBadge showInQueueInView:self];
    }];
}

- (void)restore {
    _contentView.hidden = NO;
    [_dockBadge hideAnimated:YES];
    [UIView animateWithDuration:0.3 animations:^{
        self.contentView.alpha = 1;
        self.contentView.transform = CGAffineTransformIdentity;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    } completion:^(BOOL f) {
        self->_isFocused = YES;
    }];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01) return nil;
    if (_contentView.hidden && !_dockBadge.hidden) {
        CGPoint bp = [self convertPoint:point toView:_dockBadge];
        if ([_dockBadge pointInside:bp withEvent:event])
            return [_dockBadge hitTest:bp withEvent:event];
        return nil;
    }
    if (_contentView) {
        CGPoint cp = [self convertPoint:point toView:_contentView];
        if ([_contentView pointInside:cp withEvent:event]) {
            if (_isFocused) {
                UIView *hv = [_contentView hitTest:cp withEvent:event];
                return hv ?: _contentView;
            }
            return self;
        }
    }
    if (g_touchPassthroughMode) return nil;
    if (_isFocused) return self;
    return nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    CGPoint p = [t locationInView:self];
    if (_contentView && !_contentView.hidden) {
        CGPoint cp = [self convertPoint:p toView:_contentView];
        if ([_contentView pointInside:cp withEvent:event]) {
            _dragStart = p;
            _contentStart = _contentView.center;
            if (!_isFocused) {
                _isFocused = YES;
                [UIView animateWithDuration:0.25 animations:^{
                    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
                    self.contentView.alpha = 1.0;
                }];
            }
            return;
        }
    }
    if (_isFocused) {
        _isFocused = NO;
        [UIView animateWithDuration:0.25 animations:^{
            self.backgroundColor = [UIColor clearColor];
            self.contentView.alpha = 0.3;
        }];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_contentView || _contentView.hidden || !_isFocused) return;
    UITouch *t = [touches anyObject];
    CGPoint p = [t locationInView:self];
    CGFloat dx = p.x - _dragStart.x;
    CGFloat dy = p.y - _dragStart.y;
    CGPoint nc = CGPointMake(_contentStart.x + dx, _contentStart.y + dy);
    CGFloat hw = _contentView.frame.size.width / 2;
    CGFloat hh = _contentView.frame.size.height / 2;
    CGFloat st = [VLDockBadge safeTopMargin];
    nc.x = MAX(hw - 50, MIN(self.bounds.size.width - hw + 50, nc.x));
    nc.y = MAX(st + hh, MIN(self.bounds.size.height - hh + 30, nc.y));
    _contentView.center = nc;
}

@end


#pragma mark - VLWatchOverlayImpl

@interface VLWatchOverlayImpl : NSObject <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) VLWatchContainerView *containerView;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSMutableArray<VLWatchHit *> *recentHits;
@property (nonatomic, assign) BOOL showingHits; // YES=hits列表, NO=slots列表
@property (nonatomic, assign) uint32_t selectedSlot;
@end

static VLWatchOverlayImpl *g_watchOverlay = nil;

@implementation VLWatchOverlayImpl

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_watchOverlay = [[VLWatchOverlayImpl alloc] init];
    });
    return g_watchOverlay;
}

- (instancetype)init {
    if (self = [super init]) {
        _recentHits = [NSMutableArray array];
        _showingHits = NO;
        [self setupHitCallback];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onLanguageChanged)
                                                     name:@"VansonLanguageChanged"
                                                   object:nil];
    }
    return self;
}

- (void)setupHitCallback {
    __weak typeof(self) ws = self;
    [VLDebugEngine shared].hitCallback = ^(VLWatchHit *hit) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        [ss.recentHits insertObject:hit atIndex:0];
        if (ss.recentHits.count > 50) {
            [ss.recentHits removeObjectsInRange:NSMakeRange(50, ss.recentHits.count - 50)];
        }
        [ss updateStatus];
        if (ss.showingHits) {
            [ss.tableView reloadData];
        }
        // Notify panel about new hit
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"VLWatchHitReceived"
                                                                object:nil
                                                              userInfo:@{@"hit": hit}];
        });
    };
}

- (void)showInWindow:(UIWindow *)window {
    if (_containerView.superview && !_containerView.hidden && !_panelView.hidden) {
        [self reloadData];
        return;
    }
    if (!_containerView) [self setupUI];
    
    _containerView.frame = window.bounds;
    _containerView.hidden = NO;
    _panelView.hidden = NO;
    _containerView.alpha = 0;
    
    if (!_containerView.superview) [window addSubview:_containerView];
    [window bringSubviewToFront:_containerView];
    
    [self reloadData];
    
    _panelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8
          initialSpringVelocity:0.5 options:0 animations:^{
        self->_containerView.alpha = 1;
        self->_panelView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)showMinimizedInWindow:(UIWindow *)window {
    if (!_containerView) [self setupUI];
    _containerView.frame = window.bounds;
    _containerView.hidden = NO;
    _containerView.alpha = 1;
    _containerView.backgroundColor = [UIColor clearColor];
    _panelView.hidden = YES;
    _containerView.isFocused = NO;
    if (!_containerView.superview) [window addSubview:_containerView];
    [_containerView.dockBadge showInQueueInView:_containerView];
}

- (void)hide {
    [UIView animateWithDuration:0.2 animations:^{
        self->_panelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        self->_containerView.alpha = 0;
    } completion:^(BOOL f) {
        self->_containerView.hidden = YES;
        self->_panelView.transform = CGAffineTransformIdentity;
        CGFloat sw = self->_containerView.bounds.size.width;
        CGFloat sh = self->_containerView.bounds.size.height;
        self->_panelView.center = CGPointMake(sw / 2, sh / 2);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"VLWindowDidCloseNotification"
                                                            object:nil
                                                          userInfo:@{@"tag": @1005}];
    }];
}

- (BOOL)isVisible {
    return _containerView && _containerView.superview && !_containerView.hidden && !_panelView.hidden;
}

- (void)setupUI {
    CGRect sb = [UIScreen mainScreen].bounds;
    _containerView = [[VLWatchContainerView alloc] initWithFrame:sb];
    _containerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    
    CGFloat sw = sb.size.width, sh = sb.size.height;
    CGFloat w = MIN(sw * 0.9, 360), h = MIN(sh * 0.6, 440);
    
    _panelView = [[UIView alloc] initWithFrame:CGRectMake((sw-w)/2, (sh-h)/2, w, h)];
    _panelView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.96];
    _panelView.layer.cornerRadius = 14;
    _panelView.layer.borderWidth = 1.5;
    _panelView.layer.borderColor = [UIColor cyanColor].CGColor;
    _panelView.layer.shadowColor = [UIColor cyanColor].CGColor;
    _panelView.layer.shadowRadius = 15;
    _panelView.layer.shadowOpacity = 0.3;
    [_containerView addSubview:_panelView];
    _containerView.contentView = _panelView;
    
    UIColor *accent = [UIColor cyanColor];
    
    // Title
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 140, 24)];
    _titleLabel.text = VL(@"Watch_Title");
    _titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:14];
    _titleLabel.textColor = accent;
    [_panelView addSubview:_titleLabel];
    
    // Status
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 30, w - 80, 16)];
    _statusLabel.font = [UIFont fontWithName:@"Menlo" size:10];
    _statusLabel.textColor = [accent colorWithAlphaComponent:0.6];
    [_panelView addSubview:_statusLabel];
    
    // Minimize button
    UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    minBtn.frame = CGRectMake(w - 36, 6, 30, 30);
    [minBtn setTitle:@"-" forState:UIControlStateNormal];
    [minBtn setTitleColor:[accent colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
    minBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [minBtn addTarget:self action:@selector(onMinimize) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:minBtn];
    
    // 大中小缩放按钮
    VLPanelAddSizeButtons(_panelView, sb, w, h);
    
    // Toggle button (Slots <-> Hits)
    UIButton *toggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    toggleBtn.frame = CGRectMake(w - 110, 8, 70, 26);
    toggleBtn.tag = 2001;
    toggleBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11];
    [toggleBtn setTitleColor:accent forState:UIControlStateNormal];
    toggleBtn.layer.borderColor = accent.CGColor;
    toggleBtn.layer.borderWidth = 1;
    toggleBtn.layer.cornerRadius = 13;
    [toggleBtn addTarget:self action:@selector(onToggleView) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:toggleBtn];
    
    // Table
    CGFloat listTop = 52;
    CGFloat listH = h - listTop - 52;
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(6, listTop, w - 12, listH)
                                              style:UITableViewStylePlain];
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.rowHeight = 56;
    _tableView.layer.cornerRadius = 8;
    [_panelView addSubview:_tableView];
    
    // Bottom: Add + Clear buttons
    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.frame = CGRectMake(12, h - 44, (w - 36) / 2, 32);
    addBtn.tag = 2002;
    addBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [addBtn setTitleColor:accent forState:UIControlStateNormal];
    addBtn.layer.borderColor = accent.CGColor;
    addBtn.layer.borderWidth = 1;
    addBtn.layer.cornerRadius = 16;
    addBtn.backgroundColor = [accent colorWithAlphaComponent:0.08];
    [addBtn addTarget:self action:@selector(onAddWatch) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:addBtn];
    
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(w / 2 + 6, h - 44, (w - 36) / 2, 32);
    clearBtn.tag = 2003;
    clearBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [clearBtn setTitleColor:[accent colorWithAlphaComponent:0.6] forState:UIControlStateNormal];
    clearBtn.layer.borderColor = [accent colorWithAlphaComponent:0.4].CGColor;
    clearBtn.layer.borderWidth = 1;
    clearBtn.layer.cornerRadius = 16;
    [clearBtn addTarget:self action:@selector(onClearAll) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:clearBtn];
    
    [self updateLabels];
}

- (void)updateLabels {
    _titleLabel.text = VL(@"Watch_Title");
    
    UIButton *toggleBtn = [_panelView viewWithTag:2001];
    [toggleBtn setTitle:(_showingHits ? VL(@"Watch_Slots") : VL(@"Watch_Hits"))
               forState:UIControlStateNormal];
    
    UIButton *addBtn = [_panelView viewWithTag:2002];
    [addBtn setTitle:VL(@"Watch_Add") forState:UIControlStateNormal];
    
    UIButton *clearBtn = [_panelView viewWithTag:2003];
    [clearBtn setTitle:VL(@"Watch_ClearAll") forState:UIControlStateNormal];
}

- (void)updateStatus {
    VLDebugEngine *engine = [VLDebugEngine shared];
    _statusLabel.text = [NSString stringWithFormat:@"%@ %u/%u | %@ %lu",
                         VL(@"Watch_Active"), engine.activeCount, engine.maxSlots,
                         VL(@"Watch_Hits"), (unsigned long)_recentHits.count];
}

- (void)onLanguageChanged {
    [self updateLabels];
    [self updateStatus];
    [_tableView reloadData];
}

- (void)reloadData {
    [self updateLabels];
    [self updateStatus];
    [_tableView reloadData];
}

- (void)onMinimize {
    [_containerView minimize];
}

- (void)onToggleView {
    _showingHits = !_showingHits;
    [self updateLabels];
    [_tableView reloadData];
}

- (void)onAddWatch {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Watch_Add")
                                                               message:VL(@"Watch_Add_Msg")
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"0x...";
        tf.font = [UIFont fontWithName:@"Menlo" size:14];
    }];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Btn_OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *addrStr = ac.textFields.firstObject.text;
        if (!addrStr || addrStr.length == 0) return;
        uint64_t addr = strtoull(addrStr.UTF8String, NULL, 16);
        if (addr == 0) {
            showToast(VL(@"Watch_Err_InvalidAddr"));
            return;
        }
        [VLWatchOverlay addWatchForAddress:addr];
    }]];
    
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
}

- (void)onClearAll {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:VL(@"Watch_ClearAll")
                                                               message:VL(@"Watch_ClearAll_Msg")
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:VL(@"Alert_Confirm") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[VLDebugEngine shared] removeAllWatchpoints];
        [self->_recentHits removeAllObjects];
        [self reloadData];
        showToast(VL(@"Watch_Cleared"));
    }]];
    
    UIViewController *root = GetSafeWindow().rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:ac animated:YES completion:nil];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self isDasmTable:tableView]) {
        NSArray *lines = objc_getAssociatedObject(tableView, "dasmLines");
        return lines ? (NSInteger)lines.count : 0;
    }
    if (_showingHits) return _recentHits.count;
    return [VLDebugEngine shared].maxSlots;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIColor *accent = [UIColor cyanColor];

    // Disassembly table
    if ([self isDasmTable:tableView]) {
        NSArray<NSDictionary *> *lines = objc_getAssociatedObject(tableView, "dasmLines");
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DasmCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DasmCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:10];
            cell.textLabel.numberOfLines = 1;
            cell.textLabel.adjustsFontSizeToFitWidth = YES;
            cell.textLabel.minimumScaleFactor = 0.7;
        }

        if (indexPath.row < (NSInteger)lines.count) {
            NSDictionary *l = lines[indexPath.row];
            BOOL isPC = [l[@"isPC"] boolValue];
            NSNumber *selIdx = objc_getAssociatedObject(tableView, "selIdx");
            BOOL isSel = (selIdx && [selIdx integerValue] == indexPath.row);
            NSString *marker = isPC ? @"▶" : (isSel ? @"▸" : @" ");
            cell.textLabel.text = [NSString stringWithFormat:@"%@ %08llX  %@  %@",
                                   marker, [l[@"offset"] unsignedLongLongValue], l[@"hex"], l[@"mnemonic"]];
            if (isSel) {
                cell.backgroundColor = [accent colorWithAlphaComponent:0.15];
                cell.textLabel.textColor = [UIColor whiteColor];
            } else if (isPC) {
                cell.backgroundColor = [accent colorWithAlphaComponent:0.08];
                cell.textLabel.textColor = [UIColor whiteColor];
            } else {
                cell.backgroundColor = [UIColor clearColor];
                cell.textLabel.textColor = [accent colorWithAlphaComponent:0.8];
            }
        }
        return cell;
    }

    if (_showingHits) {
        // Hit 列表
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"HitCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"HitCell"];
            cell.backgroundColor = [accent colorWithAlphaComponent:0.05];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.layer.cornerRadius = 6;
            cell.textLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
            cell.textLabel.textColor = accent;
            cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:10];
            cell.detailTextLabel.textColor = [accent colorWithAlphaComponent:0.6];
            cell.detailTextLabel.numberOfLines = 2;
        }
        
        if (indexPath.row < (NSInteger)_recentHits.count) {
            VLWatchHit *hit = _recentHits[indexPath.row];
            cell.textLabel.text = [NSString stringWithFormat:@"%@ + 0x%llX",
                                   hit.imageName, hit.offset];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"PC: 0x%llX | Addr: 0x%llX",
                                         hit.pc, hit.address];
        }
        return cell;
    }
    
    // Slot 列表
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SlotCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SlotCell"];
        cell.backgroundColor = [accent colorWithAlphaComponent:0.05];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.layer.cornerRadius = 6;
        cell.textLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:12];
        cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:10];
        cell.detailTextLabel.textColor = [accent colorWithAlphaComponent:0.6];
        
        UIButton *delBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        delBtn.tag = 300;
        delBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        [delBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        [cell.contentView addSubview:delBtn];
    }
    
    uint32_t idx = (uint32_t)indexPath.row;
    VLDebugEngine *engine = [VLDebugEngine shared];
    NSArray<VLWatchHit *> *hits = [engine hitsForSlot:idx];
    BOOL active = [engine isSlotActive:idx];
    
    if (active) {
        uint64_t addr = [engine slotAddress:idx];
        cell.textLabel.text = [NSString stringWithFormat:@"[%u] 0x%llX", idx, addr];
        cell.textLabel.textColor = accent;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %lu",
                                     VL(@"Watch_Hits"), (unsigned long)hits.count];
        cell.backgroundColor = [accent colorWithAlphaComponent:0.1];
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"[%u] %@", idx, VL(@"Watch_Empty")];
        cell.textLabel.textColor = [accent colorWithAlphaComponent:0.4];
        cell.detailTextLabel.text = @"--";
        cell.backgroundColor = [accent colorWithAlphaComponent:0.03];
    }
    
    UIButton *delBtn = [cell.contentView viewWithTag:300];
    CGFloat cw = tableView.bounds.size.width - 12;
    delBtn.frame = CGRectMake(cw - 55, 13, 50, 30);
    [delBtn setTitle:VL(@"Btn_Delete") forState:UIControlStateNormal];
    delBtn.hidden = !active;
    objc_setAssociatedObject(delBtn, "slotIdx", @(idx), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [delBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [delBtn addTarget:self action:@selector(onDeleteSlot:) forControlEvents:UIControlEventTouchUpInside];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Disasm table: select instruction and activate toolbar
    if ([self isDasmTable:tableView]) {
        NSArray<NSDictionary *> *lines = objc_getAssociatedObject(tableView, "dasmLines");
        VLWatchHit *hit = objc_getAssociatedObject(tableView, "dasmHit");
        UIView *overlay = objc_getAssociatedObject(tableView, "dasmOverlay");
        if (!lines || indexPath.row >= (NSInteger)lines.count || !hit) return;
        objc_setAssociatedObject(tableView, "selIdx", @(indexPath.row), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [tableView reloadData];
        [self showActionsForInstructionAtIndex:indexPath.row lines:lines hit:hit overlay:overlay];
        return;
    }

    if (!_showingHits) return;
    if (indexPath.row >= (NSInteger)_recentHits.count) return;
    
    VLWatchHit *hit = _recentHits[indexPath.row];
    [self showHitDetail:hit];
}

- (void)onDeleteSlot:(UIButton *)sender {
    NSNumber *idx = objc_getAssociatedObject(sender, "slotIdx");
    if (!idx) return;
    [[VLDebugEngine shared] removeWatchpoint:[idx unsignedIntValue]];
    [self reloadData];
    showToast(VL(@"Watch_Removed"));
}

#pragma mark - Disassembly Panel

- (void)showHitDetail:(VLWatchHit *)hit {
    [self showDisasmPanelForHit:hit];
}

- (void)showDisasmPanelForHit:(VLWatchHit *)hit {
    UIColor *accent = [UIColor cyanColor];
    UIColor *bgColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.98];

    // Fetch full function disassembly (prologue → epilogue, capped at 1024 insns)
    NSArray<NSDictionary *> *lines = [[VLDebugEngine shared] disassembleFunctionAt:hit.pc
                                                                        moduleName:hit.imageName];

    // Full-screen overlay
    CGRect sb = [UIScreen mainScreen].bounds;
    UIView *overlay = [[UIView alloc] initWithFrame:sb];
    overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    overlay.tag = 9900;

    CGFloat sw = sb.size.width, sh = sb.size.height;
    CGFloat pw = MIN(sw * 0.95, 380), ph = MIN(sh * 0.85, 640);
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake((sw-pw)/2, (sh-ph)/2, pw, ph)];
    panel.backgroundColor = bgColor;
    panel.layer.cornerRadius = 14;
    panel.layer.borderWidth = 1.5;
    panel.layer.borderColor = accent.CGColor;
    panel.clipsToBounds = YES;
    panel.tag = 9950;
    [overlay addSubview:panel];

    // S/M/L size buttons (居中标题栏)
    VLPanelAddSizeButtons(panel, sb, pw, ph);

    // Header: title (左侧，不会挡住居中的 SML)
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, pw * 0.3, 20)];
    titleLbl.text = VL(@"Inspector_Title");
    titleLbl.font = [UIFont fontWithName:@"Menlo-Bold" size:11];
    titleLbl.textColor = accent;
    titleLbl.adjustsFontSizeToFitWidth = YES;
    titleLbl.minimumScaleFactor = 0.7;
    [panel addSubview:titleLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(pw - 40, 4, 34, 28);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[accent colorWithAlphaComponent:0.7] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [closeBtn addTarget:self action:@selector(dismissDisasmOverlay:) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:closeBtn];

    // Hit info header
    UILabel *infoLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 28, pw - 24, 36)];
    infoLbl.numberOfLines = 2;
    infoLbl.font = [UIFont fontWithName:@"Menlo" size:9.5];
    infoLbl.textColor = [accent colorWithAlphaComponent:0.6];
    infoLbl.text = [NSString stringWithFormat:@"%@ + 0x%llX  PC: 0x%llX\nValue: %llu (0x%llX)",
                    hit.imageName, hit.offset, hit.pc, hit.newValue, hit.newValue];
    [panel addSubview:infoLbl];

    // Layout: table -> inline toolbar -> stack trace -> bottom bar
    CGFloat tableTop = 68;
    CGFloat toolbarH = 80;  // inline patch toolbar
    CGFloat stackH = MIN(hit.stackTrace.count, (NSUInteger)4) * 16 + 22;
    CGFloat bottomBarH = 36;
    CGFloat tableH = ph - tableTop - toolbarH - stackH - bottomBarH - 8;

    // Disassembly table
    UITableView *dasmTable = [[UITableView alloc] initWithFrame:CGRectMake(4, tableTop, pw - 8, tableH)
                                                          style:UITableViewStylePlain];
    dasmTable.backgroundColor = [UIColor clearColor];
    dasmTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    dasmTable.rowHeight = 28;
    dasmTable.tag = 9901;
    dasmTable.layer.cornerRadius = 6;

    objc_setAssociatedObject(dasmTable, "dasmLines", lines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(dasmTable, "dasmHit", hit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(dasmTable, "dasmOverlay", overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    dasmTable.delegate = self;
    dasmTable.dataSource = self;
    [panel addSubview:dasmTable];

    // Scroll to PC row
    NSInteger pcRow = -1;
    for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
        if ([lines[i][@"isPC"] boolValue]) { pcRow = i; break; }
    }
    if (pcRow >= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [dasmTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:pcRow inSection:0]
                             atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        });
    }

    // ── Inline Patch Toolbar ──
    CGFloat tbY = tableTop + tableH + 2;
    UIView *toolbar = [[UIView alloc] initWithFrame:CGRectMake(4, tbY, pw - 8, toolbarH)];
    toolbar.backgroundColor = [accent colorWithAlphaComponent:0.06];
    toolbar.layer.cornerRadius = 8;
    toolbar.layer.borderWidth = 0.5;
    toolbar.layer.borderColor = [accent colorWithAlphaComponent:0.2].CGColor;
    toolbar.tag = 9902;
    [panel addSubview:toolbar];

    // Selected instruction label
    UILabel *selLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, toolbar.bounds.size.width - 16, 16)];
    selLabel.tag = 9903;
    selLabel.font = [UIFont fontWithName:@"Menlo" size:9];
    selLabel.textColor = [accent colorWithAlphaComponent:0.5];
    selLabel.text = @"← Tap instruction to select";
    [toolbar addSubview:selLabel];

    // Input field row
    CGFloat inputY = 22;
    CGFloat inputW = toolbar.bounds.size.width - 80;
    UITextField *patchField = [[UITextField alloc] initWithFrame:CGRectMake(8, inputY, inputW, 28)];
    patchField.tag = 9904;
    patchField.placeholder = VL(@"Inspector_PatchHint");
    patchField.font = [UIFont fontWithName:@"Menlo" size:11];
    patchField.textColor = [UIColor whiteColor];
    patchField.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    patchField.layer.cornerRadius = 6;
    patchField.layer.borderWidth = 0.5;
    patchField.layer.borderColor = [accent colorWithAlphaComponent:0.3].CGColor;
    patchField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 28)];
    patchField.leftViewMode = UITextFieldViewModeAlways;
    patchField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    patchField.autocorrectionType = UITextAutocorrectionTypeNo;
    patchField.returnKeyType = UIReturnKeyDone;
    patchField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:patchField.placeholder ?: @""
            attributes:@{NSForegroundColorAttributeName: [accent colorWithAlphaComponent:0.3],
                         NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:10]}];
    patchField.enabled = NO; // disabled until row selected
    // Done toolbar for keyboard dismissal
    UIToolbar *kbToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, pw, 36)];
    kbToolbar.barStyle = UIBarStyleBlack;
    kbToolbar.translucent = YES;
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:VL(@"Btn_Done")
                                                                style:UIBarButtonItemStyleDone
                                                               target:self
                                                               action:@selector(onPatchFieldDone:)];
    doneItem.tintColor = accent;
    kbToolbar.items = @[flex, doneItem];
    patchField.inputAccessoryView = kbToolbar;
    [toolbar addSubview:patchField];

    // Apply button
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    applyBtn.frame = CGRectMake(toolbar.bounds.size.width - 68, inputY, 60, 28);
    applyBtn.tag = 9905;
    [applyBtn setTitle:VL(@"Inspector_Patch") forState:UIControlStateNormal];
    [applyBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    applyBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:10];
    applyBtn.backgroundColor = accent;
    applyBtn.layer.cornerRadius = 6;
    applyBtn.enabled = NO;
    applyBtn.alpha = 0.4;
    [toolbar addSubview:applyBtn];

    // Quick action buttons row
    CGFloat qY = inputY + 32;
    CGFloat qBtnW = (toolbar.bounds.size.width - 16 - 20) / 5; // 5 buttons with 4px gaps
    NSArray *qTitles = @[VL(@"Inspector_NOP"), VL(@"Inspector_RET"),
                         VL(@"Inspector_ToRVA"), VL(@"Inspector_CopyHex"), @"Offset"];
    NSArray *qTags = @[@9910, @9911, @9912, @9913, @9914];

    for (NSInteger i = 0; i < 5; i++) {
        UIButton *qBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        qBtn.frame = CGRectMake(8 + i * (qBtnW + 4), qY, qBtnW, 22);
        qBtn.tag = [qTags[i] integerValue];
        [qBtn setTitle:qTitles[i] forState:UIControlStateNormal];
        [qBtn setTitleColor:accent forState:UIControlStateNormal];
        qBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:8.5];
        qBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
        qBtn.titleLabel.minimumScaleFactor = 0.6;
        qBtn.layer.borderColor = [accent colorWithAlphaComponent:0.3].CGColor;
        qBtn.layer.borderWidth = 0.5;
        qBtn.layer.cornerRadius = 4;
        qBtn.enabled = NO;
        qBtn.alpha = 0.4;
        [toolbar addSubview:qBtn];
    }

    // Store references for toolbar actions
    objc_setAssociatedObject(toolbar, "dasmTable", dasmTable, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(toolbar, "dasmHit", hit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(toolbar, "dasmOverlay", overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(dasmTable, "toolbar", toolbar, OBJC_ASSOCIATION_ASSIGN);

    // Wire up apply button
    objc_setAssociatedObject(applyBtn, "toolbar", toolbar, OBJC_ASSOCIATION_ASSIGN);
    [applyBtn addTarget:self action:@selector(onToolbarApply:) forControlEvents:UIControlEventTouchUpInside];

    // Wire up quick buttons
    for (NSInteger i = 9910; i <= 9914; i++) {
        UIButton *qBtn = [toolbar viewWithTag:i];
        objc_setAssociatedObject(qBtn, "toolbar", toolbar, OBJC_ASSOCIATION_ASSIGN);
        [qBtn addTarget:self action:@selector(onToolbarQuickAction:) forControlEvents:UIControlEventTouchUpInside];
    }

    // Stack trace section
    CGFloat stackTop = tbY + toolbarH + 4;
    UILabel *stackTitle = [[UILabel alloc] initWithFrame:CGRectMake(12, stackTop, pw - 24, 16)];
    stackTitle.text = VL(@"Watch_StackTrace");
    stackTitle.font = [UIFont fontWithName:@"Menlo-Bold" size:9];
    stackTitle.textColor = [accent colorWithAlphaComponent:0.6];
    [panel addSubview:stackTitle];

    CGFloat sy = stackTop + 18;
    NSUInteger maxFrames = MIN(hit.stackTrace.count, (NSUInteger)4);
    for (NSUInteger i = 0; i < maxFrames; i++) {
        VLStackFrame *f = hit.stackTrace[i];
        UILabel *fl = [[UILabel alloc] initWithFrame:CGRectMake(12, sy, pw - 24, 14)];
        fl.font = [UIFont fontWithName:@"Menlo" size:8.5];
        fl.textColor = [accent colorWithAlphaComponent:0.4];
        fl.text = [NSString stringWithFormat:@"#%lu %@ + 0x%llX", (unsigned long)i, f.imageName, f.offset];
        [panel addSubview:fl];
        sy += 16;
    }

    // Bottom bar: Copy All + Copy Offset + Send RVA + ARM Converter
    CGFloat barY = ph - bottomBarH - 2;
    CGFloat btnW = (pw - 28) / 4;

    UIButton *copyAllBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyAllBtn.frame = CGRectMake(8, barY, btnW, 30);
    [copyAllBtn setTitle:VL(@"Inspector_CopyAll") forState:UIControlStateNormal];
    [copyAllBtn setTitleColor:accent forState:UIControlStateNormal];
    copyAllBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:9];
    copyAllBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    copyAllBtn.titleLabel.minimumScaleFactor = 0.6;
    copyAllBtn.layer.borderColor = [accent colorWithAlphaComponent:0.3].CGColor;
    copyAllBtn.layer.borderWidth = 0.5;
    copyAllBtn.layer.cornerRadius = 15;
    objc_setAssociatedObject(copyAllBtn, "dasmLines", lines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(copyAllBtn, "dasmHit", hit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [copyAllBtn addTarget:self action:@selector(onCopyAllDisasm:) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:copyAllBtn];

    UIButton *copyOffBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyOffBtn.frame = CGRectMake(8 + btnW + 4, barY, btnW, 30);
    [copyOffBtn setTitle:VL(@"Watch_CopyOffset") forState:UIControlStateNormal];
    [copyOffBtn setTitleColor:accent forState:UIControlStateNormal];
    copyOffBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:9];
    copyOffBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    copyOffBtn.titleLabel.minimumScaleFactor = 0.6;
    copyOffBtn.layer.borderColor = [accent colorWithAlphaComponent:0.3].CGColor;
    copyOffBtn.layer.borderWidth = 0.5;
    copyOffBtn.layer.cornerRadius = 15;
    objc_setAssociatedObject(copyOffBtn, "dasmHit", hit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [copyOffBtn addTarget:self action:@selector(onCopyHitOffset:) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:copyOffBtn];

    UIButton *rvaBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    rvaBtn.frame = CGRectMake(8 + (btnW + 4) * 2, barY, btnW, 30);
    [rvaBtn setTitle:VL(@"Watch_SendToRVA") forState:UIControlStateNormal];
    [rvaBtn setTitleColor:accent forState:UIControlStateNormal];
    rvaBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:9];
    rvaBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    rvaBtn.titleLabel.minimumScaleFactor = 0.6;
    rvaBtn.layer.borderColor = [accent colorWithAlphaComponent:0.3].CGColor;
    rvaBtn.layer.borderWidth = 0.5;
    rvaBtn.layer.cornerRadius = 15;
    objc_setAssociatedObject(rvaBtn, "dasmHit", hit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(rvaBtn, "toolbar", toolbar, OBJC_ASSOCIATION_ASSIGN);
    [rvaBtn addTarget:self action:@selector(onSendHitToRVA:) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:rvaBtn];

    UIButton *armBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    armBtn.frame = CGRectMake(8 + (btnW + 4) * 3, barY, btnW, 30);
    [armBtn setTitle:@"ARM Conv" forState:UIControlStateNormal];
    [armBtn setImage:[UIImage systemImageNamed:@"safari"] forState:UIControlStateNormal];
    armBtn.tintColor = [UIColor systemBlueColor];
    [armBtn setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    armBtn.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:8];
    armBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    armBtn.titleLabel.minimumScaleFactor = 0.5;
    armBtn.layer.borderColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.3].CGColor;
    armBtn.layer.borderWidth = 0.5;
    armBtn.layer.cornerRadius = 15;
    [armBtn addTarget:self action:@selector(onOpenARMConverter) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:armBtn];

    // ── Drag support: store panel ref on overlay for touch handling ──
    objc_setAssociatedObject(overlay, "dragPanel", panel, OBJC_ASSOCIATION_ASSIGN);
    // Add pan gesture for dragging
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(handleInspectorDrag:)];
    [overlay addGestureRecognizer:panGesture];

    // Show with animation
    UIWindow *w = GetSafeWindow();
    [w addSubview:overlay];
    panel.transform = CGAffineTransformMakeScale(0.92, 0.92);
    overlay.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{
        overlay.alpha = 1;
        panel.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismissDisasmOverlay:(UIButton *)sender {
    UIView *overlay = sender.superview.superview;
    if (!overlay || overlay.tag != 9900) {
        UIView *v = sender.superview;
        while (v && v.tag != 9900) v = v.superview;
        overlay = v;
    }
    if (!overlay) return;
    [UIView animateWithDuration:0.2 animations:^{
        overlay.alpha = 0;
    } completion:^(BOOL f) {
        [overlay removeFromSuperview];
    }];
}

- (void)handleInspectorDrag:(UIPanGestureRecognizer *)gesture {
    UIView *overlay = gesture.view;
    UIView *panel = objc_getAssociatedObject(overlay, "dragPanel");
    if (!panel) return;

    CGPoint translation = [gesture translationInView:overlay];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        // 只有触摸在 panel 区域内才允许拖动
        CGPoint loc = [gesture locationInView:overlay];
        // 考虑 transform 缩放后的实际区域
        CGAffineTransform t = panel.transform;
        CGFloat sx = t.a, sy = t.d;
        CGFloat realW = panel.bounds.size.width * sx;
        CGFloat realH = panel.bounds.size.height * sy;
        CGRect realFrame = CGRectMake(panel.center.x - realW/2, panel.center.y - realH/2, realW, realH);
        if (!CGRectContainsPoint(realFrame, loc)) {
            gesture.enabled = NO;
            gesture.enabled = YES;
            return;
        }
        objc_setAssociatedObject(overlay, "dragStartCenter",
            [NSValue valueWithCGPoint:panel.center], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    NSValue *startVal = objc_getAssociatedObject(overlay, "dragStartCenter");
    if (!startVal) return;
    CGPoint startCenter = [startVal CGPointValue];

    panel.center = CGPointMake(startCenter.x + translation.x, startCenter.y + translation.y);

    if (gesture.state == UIGestureRecognizerStateEnded ||
        gesture.state == UIGestureRecognizerStateCancelled) {
        objc_setAssociatedObject(overlay, "dragStartCenter", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - Disasm Table DataSource (tag 9901)

- (BOOL)isDasmTable:(UITableView *)tv {
    return tv.tag == 9901;
}

// Override existing tableView methods - we need to handle both tables
// The original methods are replaced below

#pragma mark - Inline Toolbar Selection

- (void)showActionsForInstructionAtIndex:(NSInteger)idx
                                   lines:(NSArray<NSDictionary *> *)lines
                                     hit:(VLWatchHit *)hit
                                 overlay:(UIView *)overlay {
    NSDictionary *line = lines[idx];
    uint64_t offset = [line[@"offset"] unsignedLongLongValue];
    NSString *hex = line[@"hex"];
    NSString *mnemonic = line[@"mnemonic"];

    UIColor *accent = [UIColor cyanColor];

    // Find toolbar in overlay
    UIView *toolbar = nil;
    for (UIView *sub in overlay.subviews) {
        for (UIView *s2 in sub.subviews) {
            if (s2.tag == 9902) { toolbar = s2; break; }
        }
        if (toolbar) break;
    }
    if (!toolbar) return;

    // Update selected label
    UILabel *selLabel = [toolbar viewWithTag:9903];
    selLabel.text = [NSString stringWithFormat:@"▸ 0x%llX  %@  %@", offset, hex, mnemonic];
    selLabel.textColor = accent;

    // Store selected offset + module
    objc_setAssociatedObject(toolbar, "selOffset", @(offset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(toolbar, "selHex", hex, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(toolbar, "selLine", line, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Enable input + buttons
    UITextField *patchField = [toolbar viewWithTag:9904];
    patchField.enabled = YES;
    patchField.text = @"";

    UIButton *applyBtn = (UIButton *)[toolbar viewWithTag:9905];
    applyBtn.enabled = YES;
    applyBtn.alpha = 1.0;

    for (NSInteger i = 9910; i <= 9914; i++) {
        UIButton *qBtn = (UIButton *)[toolbar viewWithTag:i];
        qBtn.enabled = YES;
        qBtn.alpha = 1.0;
    }

    // Animate toolbar highlight
    [UIView animateWithDuration:0.15 animations:^{
        toolbar.backgroundColor = [accent colorWithAlphaComponent:0.1];
    } completion:^(BOOL f) {
        [UIView animateWithDuration:0.2 animations:^{
            toolbar.backgroundColor = [accent colorWithAlphaComponent:0.06];
        }];
    }];
}

#pragma mark - Toolbar Actions

- (void)onToolbarApply:(UIButton *)sender {
    UIView *toolbar = objc_getAssociatedObject(sender, "toolbar");
    if (!toolbar) return;

    UITextField *patchField = [toolbar viewWithTag:9904];
    NSString *input = [patchField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!input || input.length == 0) return;

    NSNumber *offsetNum = objc_getAssociatedObject(toolbar, "selOffset");
    VLWatchHit *hit = objc_getAssociatedObject(toolbar, "dasmHit");
    UIView *overlay = objc_getAssociatedObject(toolbar, "dasmOverlay");
    if (!offsetNum || !hit) return;

    uint64_t offset = [offsetNum unsignedLongLongValue];

    // Hex-only input
    NSString *stripped = [[input stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    NSCharacterSet *hexChars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet];
    BOOL isHex = ([stripped rangeOfCharacterFromSet:hexChars].location == NSNotFound && stripped.length > 0 && stripped.length % 2 == 0);

    if (isHex) {
        [self applyQuickPatch:stripped atOffset:offset moduleName:hit.imageName hit:hit overlay:overlay];
    } else {
        showToast(VL(@"Inspector_HexOnly"));
    }
    patchField.text = @"";
    [patchField resignFirstResponder];
}

- (void)onPatchFieldDone:(UIBarButtonItem *)sender {
    // Find the patchField — walk the key window's subviews
    UIView *overlay = nil;
    for (UIView *sub in GetSafeWindow().subviews) {
        if (sub.tag == 9900) { overlay = sub; break; }
    }
    if (!overlay) return;
    UIView *toolbar = nil;
    for (UIView *sub in overlay.subviews) {
        for (UIView *s2 in sub.subviews) {
            if (s2.tag == 9902) { toolbar = s2; break; }
        }
        if (toolbar) break;
    }
    if (!toolbar) return;
    UITextField *patchField = [toolbar viewWithTag:9904];
    [patchField resignFirstResponder];
}

- (void)onToolbarQuickAction:(UIButton *)sender {
    UIView *toolbar = objc_getAssociatedObject(sender, "toolbar");
    if (!toolbar) return;

    NSNumber *offsetNum = objc_getAssociatedObject(toolbar, "selOffset");
    NSString *selHex = objc_getAssociatedObject(toolbar, "selHex");
    NSDictionary *selLine = objc_getAssociatedObject(toolbar, "selLine");
    VLWatchHit *hit = objc_getAssociatedObject(toolbar, "dasmHit");
    if (!offsetNum || !hit) return;

    UITextField *patchField = [toolbar viewWithTag:9904];
    uint64_t offset = [offsetNum unsignedLongLongValue];

    switch (sender.tag) {
        case 9910: // NOP → fill input
            patchField.text = @"1F2003D5";
            break;
        case 9911: // RET → fill input
            patchField.text = @"C0035FD6";
            break;
        case 9912: // To RVA
            if (selLine) [self createRVAItemFromInstruction:selLine hit:hit];
            break;
        case 9913: // Copy Hex
            if (selHex) {
                [UIPasteboard generalPasteboard].string = selHex;
                showToast([NSString stringWithFormat:@"%@ %@", VL(@"Mem_Copied"), selHex]);
            }
            break;
        case 9914: { // Copy Offset
            NSString *offStr = [NSString stringWithFormat:@"0x%llX", offset];
            [UIPasteboard generalPasteboard].string = offStr;
            showToast([NSString stringWithFormat:@"%@ %@", VL(@"Mem_Copied"), offStr]);
            break;
        }
    }
}

- (void)applyQuickPatch:(NSString *)hex
               atOffset:(uint64_t)offset
             moduleName:(NSString *)moduleName
                    hit:(VLWatchHit *)hit
                overlay:(UIView *)overlay {
    NSString *origHex = nil;
    BOOL ok = [[VLDebugEngine shared] applyPatchAtOffset:offset
                                                 hexCode:hex
                                              moduleName:moduleName
                                           backupOriginal:&origHex];
    if (ok) {
        showToast(VL(@"Inspector_Patched"));
        // Refresh disassembly
        [self refreshDisasmInOverlay:overlay hit:hit];
    } else {
        showToast(VL(@"Inspector_PatchFail"));
    }
}

- (void)refreshDisasmInOverlay:(UIView *)overlay hit:(VLWatchHit *)hit {
    // Find the dasm table in the overlay
    UITableView *dasmTable = nil;
    for (UIView *sub in overlay.subviews) {
        for (UIView *s2 in sub.subviews) {
            if ([s2 isKindOfClass:[UITableView class]] && s2.tag == 9901) {
                dasmTable = (UITableView *)s2;
                break;
            }
        }
        if (dasmTable) break;
    }
    if (!dasmTable) return;

    // Re-fetch full function disassembly
    NSArray<NSDictionary *> *newLines = [[VLDebugEngine shared] disassembleFunctionAt:hit.pc
                                                                          moduleName:hit.imageName];
    objc_setAssociatedObject(dasmTable, "dasmLines", newLines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Update buttons and toolbar that hold dasmLines
    for (UIView *sub in overlay.subviews) {
        for (UIView *s2 in sub.subviews) {
            if ([s2 isKindOfClass:[UIButton class]]) {
                NSArray *btnLines = objc_getAssociatedObject(s2, "dasmLines");
                if (btnLines) {
                    objc_setAssociatedObject(s2, "dasmLines", newLines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
        }
    }

    [dasmTable reloadData];

    // Reset toolbar selection label
    UIView *toolbar = nil;
    for (UIView *sub in overlay.subviews) {
        for (UIView *s2 in sub.subviews) {
            if (s2.tag == 9902) { toolbar = s2; break; }
        }
        if (toolbar) break;
    }
    if (toolbar) {
        UILabel *selLabel = [toolbar viewWithTag:9903];
        selLabel.text = @"← Tap instruction to select";
        selLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5];
        UITextField *patchField = [toolbar viewWithTag:9904];
        patchField.enabled = NO;
        patchField.text = @"";
        UIButton *applyBtn = (UIButton *)[toolbar viewWithTag:9905];
        applyBtn.enabled = NO;
        applyBtn.alpha = 0.4;
        for (NSInteger i = 9910; i <= 9914; i++) {
            UIButton *qBtn = (UIButton *)[toolbar viewWithTag:i];
            qBtn.enabled = NO;
            qBtn.alpha = 0.4;
        }
    }
}

- (void)createRVAItemFromInstruction:(NSDictionary *)line hit:(VLWatchHit *)hit {
    uint64_t offset = [line[@"offset"] unsignedLongLongValue];
    NSString *hex = line[@"hex"];

    if (!g_rvaItems) g_rvaItems = [NSMutableArray array];

    // Check for existing RVA item with same module + offset
    VLModItem *existing = nil;
    NSInteger existingIdx = NSNotFound;
    for (NSInteger i = 0; i < (NSInteger)g_rvaItems.count; i++) {
        VLModItem *p = g_rvaItems[i];
        if (p.type == VModTypeRVA &&
            [p.moduleName isEqualToString:hit.imageName] &&
            p.rvaOffset == offset) {
            existing = p;
            existingIdx = i;
            break;
        }
    }

    VLModItem *item = [[VLModItem alloc] init];
    item.type = VModTypeRVA;
    item.uniqueId = existing ? existing.uniqueId : [[NSUUID UUID] UUIDString];
    item.note = [NSString stringWithFormat:@"[Inspector] %@ + 0x%llX %@",
                 hit.imageName, offset, line[@"mnemonic"]];
    item.moduleName = hit.imageName;
    item.rvaOffset = offset;
    item.patchHex = existing ? existing.patchHex : @"C0035FD6"; // keep existing patch or RET default
    item.originalHex = hex;
    item.isPatched = existing ? existing.isPatched : NO;
    item.bundleID = existing ? existing.bundleID : ([[NSBundle mainBundle] bundleIdentifier] ?: @"");
    item.appName = existing ? existing.appName : ([[NSBundle mainBundle] infoDictionary][@"CFBundleDisplayName"] ?: @"");
    item.createdAt = existing ? existing.createdAt : [[NSDate date] timeIntervalSince1970];
    item.author = existing ? existing.author : @"VansonMod";

    if (existing && existingIdx != NSNotFound) {
        [g_rvaItems replaceObjectAtIndex:existingIdx withObject:item];
        showToast(VL(@"Watch_RVAUpdated"));
    } else {
        [g_rvaItems addObject:item];
        showToast(VL(@"Watch_SentToRVA"));
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VLReloadList" object:nil];
}

- (void)onOpenARMConverter {
    NSURL *url = [NSURL URLWithString:@"https://armconverter.com"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)onCopyAllDisasm:(UIButton *)sender {
    NSArray<NSDictionary *> *lines = objc_getAssociatedObject(sender, "dasmLines");
    VLWatchHit *hit = objc_getAssociatedObject(sender, "dasmHit");
    if (!lines) return;

    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"%@ + 0x%llX  PC: 0x%llX\n", hit.imageName, hit.offset, hit.pc];
    [text appendString:@"---\n"];
    for (NSDictionary *l in lines) {
        NSString *marker = [l[@"isPC"] boolValue] ? @">" : @" ";
        [text appendFormat:@"%@ 0x%08llX  %@  %@\n",
         marker, [l[@"offset"] unsignedLongLongValue], l[@"hex"], l[@"mnemonic"]];
    }
    [UIPasteboard generalPasteboard].string = text;
    showToast(VL(@"Mem_Copied"));
}

- (void)onCopyHitOffset:(UIButton *)sender {
    VLWatchHit *hit = objc_getAssociatedObject(sender, "dasmHit");
    if (!hit) return;
    NSString *offStr = [NSString stringWithFormat:@"0x%llX", hit.offset];
    [UIPasteboard generalPasteboard].string = offStr;
    showToast([NSString stringWithFormat:@"%@ %@", VL(@"Mem_Copied"), offStr]);
}

- (void)onSendHitToRVA:(UIButton *)sender {
    VLWatchHit *hit = objc_getAssociatedObject(sender, "dasmHit");
    if (!hit) return;

    // 优先使用选中行
    UIView *toolbar = objc_getAssociatedObject(sender, "toolbar");
    if (toolbar) {
        NSDictionary *selLine = objc_getAssociatedObject(toolbar, "selLine");
        if (selLine) {
            [self createRVAItemFromInstruction:selLine hit:hit];
            return;
        }
    }
    // 没有选中行时使用 hit 本身
    [self createRVAItemFromHit:hit];
}

- (void)createRVAItemFromHit:(VLWatchHit *)hit {
    if (!g_rvaItems) g_rvaItems = [NSMutableArray array];

    // Check for existing RVA item with same module + offset
    VLModItem *existing = nil;
    NSInteger existingIdx = NSNotFound;
    for (NSInteger i = 0; i < (NSInteger)g_rvaItems.count; i++) {
        VLModItem *p = g_rvaItems[i];
        if (p.type == VModTypeRVA &&
            [p.moduleName isEqualToString:hit.imageName] &&
            p.rvaOffset == hit.offset) {
            existing = p;
            existingIdx = i;
            break;
        }
    }

    VLModItem *item = [[VLModItem alloc] init];
    item.type = VModTypeRVA;
    item.uniqueId = existing ? existing.uniqueId : [[NSUUID UUID] UUIDString];
    item.note = [NSString stringWithFormat:@"[Watch] %@ + 0x%llX", hit.imageName, hit.offset];
    item.moduleName = hit.imageName;
    item.rvaOffset = hit.offset;
    item.patchHex = existing ? existing.patchHex : @"C0035FD6";
    item.originalHex = existing ? existing.originalHex : @"";
    item.isPatched = existing ? existing.isPatched : NO;
    item.bundleID = existing ? existing.bundleID : ([[NSBundle mainBundle] bundleIdentifier] ?: @"");
    item.appName = existing ? existing.appName : ([[NSBundle mainBundle] infoDictionary][@"CFBundleDisplayName"] ?: @"");
    item.createdAt = existing ? existing.createdAt : [[NSDate date] timeIntervalSince1970];
    item.author = existing ? existing.author : @"VansonMod";

    if (existing && existingIdx != NSNotFound) {
        [g_rvaItems replaceObjectAtIndex:existingIdx withObject:item];
        showToast(VL(@"Watch_RVAUpdated"));
    } else {
        [g_rvaItems addObject:item];
        showToast(VL(@"Watch_SentToRVA"));
    }

    // 通知面板刷新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VLReloadList" object:nil];
}

@end


#pragma mark - VLWatchOverlay

@implementation VLWatchOverlay

+ (void)show {
    if (![VLDebugEngine isAvailable]) {
        showToast(VL(@"Watch_JailbreakOnly"));
        return;
    }
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    [[VLWatchOverlayImpl shared] showInWindow:w];
}

+ (void)showMinimized {
    if (![VLDebugEngine isAvailable]) return;
    UIWindow *w = GetSafeWindow();
    if (!w) return;
    [[VLWatchOverlayImpl shared] showMinimizedInWindow:w];
}

+ (void)hide {
    [[VLWatchOverlayImpl shared] hide];
}

+ (void)toggle {
    if ([[VLWatchOverlayImpl shared] isVisible]) {
        [self hide];
    } else {
        [self show];
    }
}

+ (BOOL)isVisible {
    return [[VLWatchOverlayImpl shared] isVisible];
}

+ (void)reloadData {
    [[VLWatchOverlayImpl shared] reloadData];
}

+ (void)addWatchForAddress:(uint64_t)address {
    if (![VLDebugEngine isAvailable]) {
        showToast(VL(@"Watch_JailbreakOnly"));
        return;
    }
    
    VLDebugEngine *engine = [VLDebugEngine shared];
    
    if (engine.activeCount >= engine.maxSlots) {
        showToast(VL(@"Watch_Err_MaxSlots"));
        return;
    }
    
    int result = [engine addWatchpoint:address type:VLWatchTypeWrite size:VLWatchSizeByte4];
    
    if (result >= 0) {
        showToast([NSString stringWithFormat:@"%@ 0x%llX [%d]", VL(@"Watch_Added"), address, result]);
        [self reloadData];
    } else {
        showToast(VL(@"Watch_Err_AddFailed"));
    }
}

+ (void)showCodeInspectorForHit:(id)hit {
    if (!hit || ![hit isKindOfClass:[VLWatchHit class]]) return;
    [[VLWatchOverlayImpl shared] showDisasmPanelForHit:(VLWatchHit *)hit];
}

@end
