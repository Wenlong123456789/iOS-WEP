/**
 * VansonLoader - 精简内存页
 * 「测试1」「测试二」按钮：按固定流程执行搜索与修改
 */

#import "VLPanel+Internal.h"

@implementation VPanelImpl (Memory)

- (void)setupMemoryPage:(CGFloat)w {
    CGFloat bodyH = self.panelBody.frame.size.height;
    self.pageMemory = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, bodyH)];
    [self.panelBody addSubview:self.pageMemory];

    CGFloat pad = 16;
    CGFloat btnH = 48;
    CGFloat btnW = w - pad * 2;
    CGFloat gap = 12;

    // 状态标签
    self.memConsoleLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, pad, btnW, 80)];
    self.memConsoleLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.85];
    self.memConsoleLabel.font = [UIFont fontWithName:@"Menlo" size:11];
    self.memConsoleLabel.textAlignment = NSTextAlignmentLeft;
    self.memConsoleLabel.numberOfLines = 0;
    self.memConsoleLabel.text = @"就绪。点击「测试1」或「测试二」开始。";
    [self.pageMemory addSubview:self.memConsoleLabel];

    // 测试1 按钮
    UIButton *testBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    testBtn.frame = CGRectMake(pad, pad + 100, btnW, btnH);
    [testBtn setTitle:@"测试1" forState:UIControlStateNormal];
    [testBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    testBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    testBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.55 blue:0.75 alpha:1.0];
    testBtn.layer.cornerRadius = 12;
    testBtn.layer.borderWidth = 1.5;
    testBtn.layer.borderColor = [UIColor colorWithRed:0.3 green:0.85 blue:1.0 alpha:0.8].CGColor;
    [testBtn addTarget:self action:@selector(onTest1Tapped) forControlEvents:UIControlEventTouchUpInside];
    [self.pageMemory addSubview:testBtn];

    // 测试二 按钮
    UIButton *test2Btn = [UIButton buttonWithType:UIButtonTypeCustom];
    test2Btn.frame = CGRectMake(pad, pad + 100 + btnH + gap, btnW, btnH);
    [test2Btn setTitle:@"测试二" forState:UIControlStateNormal];
    [test2Btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    test2Btn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    test2Btn.backgroundColor = [UIColor colorWithRed:0.55 green:0.25 blue:0.75 alpha:1.0];
    test2Btn.layer.cornerRadius = 12;
    test2Btn.layer.borderWidth = 1.5;
    test2Btn.layer.borderColor = [UIColor colorWithRed:0.85 green:0.5 blue:1.0 alpha:0.8].CGColor;
    [test2Btn addTarget:self action:@selector(onTest2Tapped) forControlEvents:UIControlEventTouchUpInside];
    [self.pageMemory addSubview:test2Btn];

    // 结果数量标签
    self.memResultsCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, pad + 100 + (btnH + gap) * 2, btnW, 24)];
    self.memResultsCountLabel.textColor = [[UIColor cyanColor] colorWithAlphaComponent:0.6];
    self.memResultsCountLabel.font = [UIFont fontWithName:@"Menlo" size:12];
    self.memResultsCountLabel.textAlignment = NSTextAlignmentCenter;
    self.memResultsCountLabel.text = @"";
    [self.pageMemory addSubview:self.memResultsCountLabel];

    self.pageMemory.frame = CGRectMake(0, 0, w, MAX(bodyH, pad + 100 + (btnH + gap) * 2 + 40));
    self.panelBody.contentSize = self.pageMemory.frame.size;
}

- (void)appendStatus:(NSString *)line {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *old = self.memConsoleLabel.text ?: @"";
        if (old.length > 600) {
            // 截断过长日志
            NSRange r = [old rangeOfString:@"\n" options:0 range:NSMakeRange(old.length / 2, old.length / 2)];
            if (r.location != NSNotFound) {
                old = [old substringFromIndex:r.location + 1];
            }
        }
        self.memConsoleLabel.text = [old stringByAppendingFormat:@"\n%@", line];
    });
}

- (void)setStatus:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.memConsoleLabel.text = text;
    });
}

- (void)onTest1Tapped {
    [self setStatus:@"开始测试1流程…"];
    self.memResultsCountLabel.text = @"";

    VLMemEngine *engine = [VLMemEngine shared];

    // 1. 初始化内存引擎
    [engine initialize];
    [self appendStatus:[NSString stringWithFormat:@"引擎初始化: %@", engine.isReady ? @"OK" : @"未就绪(仍继续)"]];

    const uint64_t rangeStart = 0x00000000ULL;
    const uint64_t rangeEnd   = 0x2000000000ULL;
    const uint64_t nearbyRange = 30;   // ← 已改为 30

    // 2. 搜索 F32 = 0.55（指定范围）
    [self appendStatus:@"搜索 F32 0.55 …"];
    [engine scanWithMode:VMemSearchModeExact
                   value:@"0.55"
                    type:VMemDataTypeF32
              rangeStart:rangeStart
                rangeEnd:rangeEnd
              completion:^(NSUInteger count, NSString *msg) {
        [self appendStatus:[NSString stringWithFormat:@"→ 0.55 结果: %lu (%@)", (unsigned long)count, msg ?: @"ok"]];

        // 3. 临近搜索 F32 1.5，范围 30
        [self appendStatus:@"临近搜索 F32 1.5 (range=30) …"];
        [engine scanNearbyWithValue:@"1.5"
                               type:VMemDataTypeF32
                              range:nearbyRange
                         completion:^(NSUInteger count2, NSString *msg2) {
            [self appendStatus:[NSString stringWithFormat:@"→ 1.5 结果: %lu (%@)", (unsigned long)count2, msg2 ?: @"ok"]];

            // 4. 临近搜索 F32 1，范围 30
            [self appendStatus:@"临近搜索 F32 1 (range=30) …"];
            [engine scanNearbyWithValue:@"1"
                                   type:VMemDataTypeF32
                                  range:nearbyRange
                             completion:^(NSUInteger count3, NSString *msg3) {
                [self appendStatus:[NSString stringWithFormat:@"→ 1 结果: %lu (%@)", (unsigned long)count3, msg3 ?: @"ok"]];

                // 5. 筛选「地址以 0x34 结尾」且值为 1 的结果，改成 0.6
                [self applyAddressEnding34Write1To0_6:engine];
            }];
        }];
    }];
}

- (void)applyAddressEnding34Write1To0_6:(VLMemEngine *)engine {
    NSUInteger total = engine.resultCount;
    [self appendStatus:[NSString stringWithFormat:@"筛选地址以 34 结尾且值为 1 的结果 (共 %lu) …", (unsigned long)total]];

    NSUInteger matched = 0;
    NSUInteger written = 0;
    NSUInteger skipped = 0;

    for (NSUInteger i = 0; i < total; i++) {
        VLMemResultItem *item = [engine getResultAtIndex:i type:VMemDataTypeF32];
        if (!item) continue;

        uint64_t addr = item.address;

        // 地址十六进制以 34 结尾 → 低 8 位 == 0x34
        if ((addr & 0xFF) != 0x34) {
            skipped++;
            continue;
        }

        matched++;

        // 再读一次当前值，必须精确等于 1.0
        NSString *cur = [engine readAddress:addr type:VMemDataTypeF32];
        float fval = cur ? [cur floatValue] : 0.0f;

        if (fval != 1.0f) {
            skipped++;
            continue;
        }

        // 写入 0.6
        BOOL ok = [engine writeAddress:addr value:@"0.6" type:VMemDataTypeF32];
        if (ok) {
            written++;
            [self appendStatus:[NSString stringWithFormat:@"  写入 0x%llX: %@ → 0.6", addr, cur ?: @"?"]];
        } else {
            [self appendStatus:[NSString stringWithFormat:@"  写入失败 0x%llX", addr]];
        }
    }

    NSString *summary = [NSString stringWithFormat:@"完成。匹配结尾34: %lu，成功写入: %lu，跳过: %lu",
                         (unsigned long)matched, (unsigned long)written, (unsigned long)skipped];
    [self appendStatus:summary];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.memResultsCountLabel.text = summary;
        showToast(summary);
    });
}

#pragma mark - 测试二

- (void)onTest2Tapped {
    [self setStatus:@"开始测试二流程…"];
    self.memResultsCountLabel.text = @"";

    VLMemEngine *engine = [VLMemEngine shared];

    // 1. 初始化内存引擎
    [engine initialize];
    [self appendStatus:[NSString stringWithFormat:@"引擎初始化: %@", engine.isReady ? @"OK" : @"未就绪(仍继续)"]];

    const uint64_t rangeStart = 0x00000000ULL;
    const uint64_t rangeEnd   = 0x2000000000ULL;
    const uint64_t nearbyRange = 10;   // 临近搜索范围都是 10

    // 2. 搜索 F32 = 0.55（指定范围）
    [self appendStatus:@"搜索 F32 0.55 …"];
    [engine scanWithMode:VMemSearchModeExact
                   value:@"0.55"
                    type:VMemDataTypeF32
              rangeStart:rangeStart
                rangeEnd:rangeEnd
              completion:^(NSUInteger count, NSString *msg) {
        [self appendStatus:[NSString stringWithFormat:@"→ 0.55 结果: %lu (%@)", (unsigned long)count, msg ?: @"ok"]];

        // 3. 临近搜索 F32 6.656168e-43，范围 10
        [self appendStatus:@"临近搜索 F32 6.656168e-43 (range=10) …"];
        [engine scanNearbyWithValue:@"6.656168e-43"
                               type:VMemDataTypeF32
                              range:nearbyRange
                         completion:^(NSUInteger count2, NSString *msg2) {
            [self appendStatus:[NSString stringWithFormat:@"→ 6.656168e-43 结果: %lu (%@)", (unsigned long)count2, msg2 ?: @"ok"]];

            // 4. 筛选「地址以 0x34 结尾」且值为 6.656168e-43 的结果，改成 1
            [self applyAddressEnding34WriteDenormalTo1:engine];
        }];
    }];
}

- (void)applyAddressEnding34WriteDenormalTo1:(VLMemEngine *)engine {
    NSUInteger total = engine.resultCount;
    [self appendStatus:[NSString stringWithFormat:@"筛选地址以 34 结尾且值为 6.656168e-43 的结果 (共 %lu) …", (unsigned long)total]];

    NSUInteger matched = 0;
    NSUInteger written = 0;
    NSUInteger skipped = 0;

    // 目标值约等于 6.656168e-43
    const float targetVal = 6.656168e-43f;
    const float eps = 1e-45f;  // float 可表示的极小正数量级

    for (NSUInteger i = 0; i < total; i++) {
        VLMemResultItem *item = [engine getResultAtIndex:i type:VMemDataTypeF32];
        if (!item) continue;

        uint64_t addr = item.address;

        // 地址十六进制以 34 结尾 → 低 8 位 == 0x34
        if ((addr & 0xFF) != 0x34) {
            skipped++;
            continue;
        }

        matched++;

        // 再读一次当前值
        NSString *cur = [engine readAddress:addr type:VMemDataTypeF32];
        float fval = cur ? [cur floatValue] : 0.0f;

        // 判断是否接近 6.656168e-43（数值或字符串）
        BOOL isTarget = (fabsf(fval - targetVal) <= eps) || (fval == targetVal);
        if (!isTarget) {
            if (cur &&
                ([cur isEqualToString:@"6.656168e-43"] ||
                 [cur isEqualToString:@"6.656168E-43"] ||
                 [cur containsString:@"6.656168"])) {
                isTarget = YES;
            }
        }
        if (!isTarget) {
            skipped++;
            continue;
        }

        // 写入 1
        BOOL ok = [engine writeAddress:addr value:@"1" type:VMemDataTypeF32];
        if (ok) {
            written++;
            [self appendStatus:[NSString stringWithFormat:@"  写入 0x%llX: %@ → 1", addr, cur ?: @"?"]];
        } else {
            [self appendStatus:[NSString stringWithFormat:@"  写入失败 0x%llX", addr]];
        }
    }

    NSString *summary = [NSString stringWithFormat:@"测试二完成。匹配结尾34: %lu，成功写入: %lu，跳过: %lu",
                         (unsigned long)matched, (unsigned long)written, (unsigned long)skipped];
    [self appendStatus:summary];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.memResultsCountLabel.text = summary;
        showToast(summary);
    });
}

// 以下保留空实现，避免 category 缺失导致链接问题
- (void)memModeChanged {}
- (void)updateMemUIForMode {}
- (void)memTypeChanged:(UISegmentedControl *)seg {}
- (void)memType2Changed:(UISegmentedControl *)seg {}
- (void)doMemorySearch {}
- (void)doMemoryFilter {}
- (void)memPrevPage {}
- (void)memNextPage {}
- (void)handleMemResultLongPress:(UILongPressGestureRecognizer *)gr {}
- (void)onMemFuzzySelected:(id)sender {}
- (void)updateMemLocks {}

@end
