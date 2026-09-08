/**
 * VansonLoader L2.3 - VLWindowSwitches 实现
 * 窗口开关管理页面 - 直接显示/隐藏窗口
 * 支持窗口状态持久化
 */

#import "VLWindowSwitches.h"
#import "VLMemorySearch.h"
#import "VLMemoryBrowser.h"
#import "VLToolbox.h"
#import "VLMemResults.h"
#import "VLWatchOverlay.h"
#import "../Engine/VLDebugEngine.h"
#import "../Utils/VLLocalization.h"
#import "../Utils/VLIconManager.h"

UIWindow *GetSafeWindow(void);
void showToast(NSString *msg);

// 通知名称：窗口关闭时同步开关
NSString * const VLWindowDidCloseNotification = @"VLWindowDidCloseNotification";

// 持久化 key
static NSString * const kWindowStatesKey = @"VLWindowStates";

#pragma mark - VLWindowSwitches

@implementation VLWindowSwitches

+ (void)initialize {
    if (self == [VLWindowSwitches class]) {
        // 监听窗口关闭通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onWindowClosed:)
                                                     name:VLWindowDidCloseNotification
                                                   object:nil];
    }
}

+ (void)onWindowClosed:(NSNotification *)notification {
    NSInteger tag = [notification.userInfo[@"tag"] integerValue];
    // 保存状态
    [self saveWindowState:tag isOpen:NO];
    // 通知所有开关容器同步状态
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VLSyncWindowToggle"
                                                        object:nil
                                                      userInfo:@{@"tag": @(tag), @"state": @NO}];
}

#pragma mark - 持久化

+ (void)saveWindowState:(NSInteger)tag isOpen:(BOOL)isOpen {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *states = [[defaults objectForKey:kWindowStatesKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    states[@(tag).stringValue] = @(isOpen);
    [defaults setObject:states forKey:kWindowStatesKey];
    [defaults synchronize];
}

+ (BOOL)loadWindowState:(NSInteger)tag {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *states = [defaults objectForKey:kWindowStatesKey];
    if (!states) return NO;
    NSNumber *state = states[@(tag).stringValue];
    return state ? [state boolValue] : NO;
}

+ (void)restoreWindowStates {
    // 恢复之前打开的窗口（以最小化状态）
    if ([self loadWindowState:1001] || [self loadWindowState:1004]) {
        // 内存调试和搜索结果是双生的
        [VLMemorySearchVC showMinimized];
        [VLMemResults showMinimized];
    }
    if ([self loadWindowState:1002]) {
        [VLToolbox showMinimized];
    }
    if ([self loadWindowState:1003]) {
        [VLMemoryBrowserVC showMinimized];
    }
    if ([self loadWindowState:1005] && [VLDebugEngine isAvailable]) {
        [VLWatchOverlay showMinimized];
    }
}

+ (void)setupWindowSwitchesView:(UIScrollView *)container {
    CGFloat w = container.frame.size.width;
    CGFloat y = 8;
    CGFloat boxMargin = 12;
    CGFloat boxWidth = w - boxMargin * 2;
    CGFloat rowHeight = 44;
    CGFloat rowSpacing = 8;
    
    // ═══════════════════════════════════════════
    // 1. 内存调试窗口
    // ═══════════════════════════════════════════
    [self createCompactWindowRow:VL(@"Window_MemDebug_Title")
                           width:boxWidth
                              at:y
                       container:container
                             tag:1001];
    y += rowHeight + rowSpacing;
    
    // ═══════════════════════════════════════════
    // 1.1 搜索结果窗口 (与内存调试双生)
    // ═══════════════════════════════════════════
    [self createCompactWindowRow:VL(@"Window_MemResults_Title")
                           width:boxWidth
                              at:y
                       container:container
                             tag:1004];
    y += rowHeight + rowSpacing;
    
    // ═══════════════════════════════════════════
    // 2. 工具箱窗口
    // ═══════════════════════════════════════════
    [self createCompactWindowRow:VL(@"Toolbox_Title")
                           width:boxWidth
                              at:y
                       container:container
                             tag:1002];
    y += rowHeight + rowSpacing;
    
    // ═══════════════════════════════════════════
    // 3. 内存浏览器窗口
    // ═══════════════════════════════════════════
    [self createCompactWindowRow:VL(@"Mem_Browser_Title")
                           width:boxWidth
                              at:y
                       container:container
                             tag:1003];
    y += rowHeight + rowSpacing;
    
    // ═══════════════════════════════════════════
    // 4. 硬件断点监控 (仅越狱环境)
    // ═══════════════════════════════════════════
    if ([VLDebugEngine isAvailable]) {
        [self createCompactWindowRow:VL(@"Watch_Title")
                               width:boxWidth
                                  at:y
                           container:container
                                 tag:1005];
        y += rowHeight + rowSpacing;
    }
    
    container.contentSize = CGSizeMake(w, y + 10);
}

+ (UIView *)createCompactWindowRow:(NSString *)title
                             width:(CGFloat)boxWidth
                                at:(CGFloat)y
                         container:(UIScrollView *)container
                               tag:(NSInteger)tag {
    CGFloat boxMargin = 12;
    
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(boxMargin, y, boxWidth, 44)];
    row.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.04];
    row.layer.cornerRadius = 10;
    row.layer.borderWidth = 1;
    row.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2].CGColor;
    [container addSubview:row];
    
    // 图标 (使用 VLIconManager)
    NSString *iconKey = nil;
    switch (tag) {
        case 1001: iconKey = @"memory_debug"; break;
        case 1004: iconKey = @"memory_results"; break;
        case 1002: iconKey = @"toolbox"; break;
        case 1003: iconKey = @"memory_browser"; break;
        case 1005: iconKey = @"watchpoint"; break;
    }
    
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 7, 30, 30)];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.layer.cornerRadius = 6;
    iconView.clipsToBounds = YES;
    iconView.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.1];
    
    UIImage *icon = IC(iconKey);
    if (icon) {
        iconView.image = icon;
    } else {
        // 无图标时显示首字母
        UILabel *fallback = [[UILabel alloc] initWithFrame:iconView.bounds];
        fallback.text = [title substringToIndex:1];
        fallback.textColor = [UIColor cyanColor];
        fallback.font = [UIFont boldSystemFontOfSize:14];
        fallback.textAlignment = NSTextAlignmentCenter;
        [iconView addSubview:fallback];
    }
    [row addSubview:iconView];
    
    // 标题 (居左，留出图标空间)
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(48, 0, boxWidth - 120, 44)];
    titleLabel.text = title;
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [row addSubview:titleLabel];
    
    // 开关 (替代按钮)
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.frame = CGRectMake(boxWidth - 60, 7, 51, 31);
    toggle.onTintColor = [UIColor cyanColor];
    toggle.tag = tag;
    
    // 初始化开关状态：优先使用持久化状态，其次检查窗口是否可见
    BOOL savedState = [self loadWindowState:tag];
    BOOL isWindowVisible = NO;
    switch (tag) {
        case 1001: isWindowVisible = [VLMemorySearchVC isVisible]; break;
        case 1004: isWindowVisible = [VLMemResults isVisible]; break;
        case 1002: isWindowVisible = [VLToolbox isVisible]; break;
        case 1003: isWindowVisible = [VLMemoryBrowserVC isVisible]; break;
        case 1005: isWindowVisible = [VLWatchOverlay isVisible]; break;
    }
    // 如果持久化状态为开，或者窗口可见，则开关打开
    toggle.on = savedState || isWindowVisible;
    
    [toggle addTarget:self action:@selector(onWindowToggle:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:toggle];
    
    // 监听同步通知
    [[NSNotificationCenter defaultCenter] addObserverForName:@"VLSyncWindowToggle"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        NSInteger syncTag = [note.userInfo[@"tag"] integerValue];
        BOOL state = [note.userInfo[@"state"] boolValue];
        if (toggle.tag == syncTag && toggle.on != state) {
            [toggle setOn:state animated:YES];
        }
    }];
    
    return row;
}

#pragma mark - Window Toggle Actions

+ (void)onWindowToggle:(UISwitch *)toggle {
    UIWindow *w = GetSafeWindow();
    if (!w) {
        toggle.on = NO;
        return;
    }
    
    // 获取容器以同步其他开关
    UIScrollView *container = (UIScrollView *)toggle.superview.superview;
    
    if (toggle.on) {
        // 打开窗口 - 直接显示悬浮图标状态
        // 先打开的在上面（槽位靠前）
        switch (toggle.tag) {
            case 1001: // 内存调试
                [VLMemorySearchVC showMinimized]; // 内存调试先开（在上）
                [VLMemResults showMinimized];     // 搜索结果后开（在下）
                [self syncToggle:1004 inContainer:container toState:YES];
                [self saveWindowState:1001 isOpen:YES];
                [self saveWindowState:1004 isOpen:YES];
                break;
            case 1004: // 搜索结果
                [VLMemorySearchVC showMinimized];
                [VLMemResults showMinimized];
                [self syncToggle:1001 inContainer:container toState:YES];
                [self saveWindowState:1001 isOpen:YES];
                [self saveWindowState:1004 isOpen:YES];
                break;
            case 1002:
                [VLToolbox showMinimized];
                [self saveWindowState:1002 isOpen:YES];
                break;
            case 1003:
                [VLMemoryBrowserVC showMinimized];
                [self saveWindowState:1003 isOpen:YES];
                break;
            case 1005:
                [VLWatchOverlay showMinimized];
                [self saveWindowState:1005 isOpen:YES];
                break;
        }
    } else {
        // 关闭窗口
        switch (toggle.tag) {
            case 1001: // 内存调试
                [VLMemorySearchVC hide];
                [VLMemResults hide]; // 双生：同时关闭搜索结果
                [self syncToggle:1004 inContainer:container toState:NO];
                [self saveWindowState:1001 isOpen:NO];
                [self saveWindowState:1004 isOpen:NO];
                break;
            case 1004: // 搜索结果
                [VLMemResults hide];
                [VLMemorySearchVC hide]; // 双生：同时关闭内存调试
                [self syncToggle:1001 inContainer:container toState:NO];
                [self saveWindowState:1001 isOpen:NO];
                [self saveWindowState:1004 isOpen:NO];
                break;
            case 1002:
                [VLToolbox hide];
                [self saveWindowState:1002 isOpen:NO];
                break;
            case 1003:
                [VLMemoryBrowserVC hide];
                [self saveWindowState:1003 isOpen:NO];
                break;
            case 1005:
                [VLWatchOverlay hide];
                [self saveWindowState:1005 isOpen:NO];
                break;
        }
    }
}

// 同步其他开关状态
+ (void)syncToggle:(NSInteger)tag inContainer:(UIScrollView *)container toState:(BOOL)state {
    if (!container) return;
    for (UIView *row in container.subviews) {
        for (UIView *subview in row.subviews) {
            if ([subview isKindOfClass:[UISwitch class]]) {
                UISwitch *sw = (UISwitch *)subview;
                if (sw.tag == tag && sw.on != state) {
                    [sw setOn:state animated:YES];
                }
            }
        }
    }
}

@end
