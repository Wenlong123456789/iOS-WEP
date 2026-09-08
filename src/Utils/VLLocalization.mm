/**
 * VansonLoader L2.3 - 多语言实现
 * 使用独立语言文件管理
 */

#import "VLLocalization.h"
#import "Lang/VLLangManager.hpp"

static NSString *const kLangKey = @"Vanson_Language_Setting";

@interface VLLocalization ()
@property (nonatomic, assign) NSInteger cachedLangIndex;
@end

@implementation VLLocalization

+ (instancetype)shared {
    static VLLocalization *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VLLocalization alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _cachedLangIndex = -1;
        [self initializeLanguage];
    }
    return self;
}

- (void)initializeLanguage {
    NSInteger savedLang = [[NSUserDefaults standardUserDefaults] integerForKey:kLangKey];
    [self setLanguage:savedLang];
}

- (NSString *)localizedString:(NSString *)key {
    std::string cppKey = [key UTF8String];
    std::string result = VLLangManager::shared().getString(cppKey);
    return [NSString stringWithUTF8String:result.c_str()];
}

- (void)setLanguage:(NSInteger)langIndex {
    _cachedLangIndex = langIndex;
    [[NSUserDefaults standardUserDefaults] setInteger:langIndex forKey:kLangKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 转换为 VLangCode
    VLangCode code;
    switch (langIndex) {
        case 0: code = VLangCode::Auto; break;
        case 1: code = VLangCode::EN; break;
        case 2: code = VLangCode::CN; break;
        case 3: code = VLangCode::TW; break;
        case 4: code = VLangCode::JA; break;
        case 5: code = VLangCode::KO; break;
        case 6: code = VLangCode::RU; break;
        case 7: code = VLangCode::ES; break;
        case 8: code = VLangCode::VI; break;
        case 9: code = VLangCode::TH; break;
        case 10: code = VLangCode::PT; break;
        case 11: code = VLangCode::FR; break;
        case 12: code = VLangCode::DE; break;
        case 13: code = VLangCode::AR; break;
        default: code = VLangCode::Auto; break;
    }
    
    // 如果是自动，检测系统语言
    if (code == VLangCode::Auto) {
        code = [self detectSystemLanguage];
    }
    
    VLLangManager::shared().setLanguage(code);
    
    // 发送语言变更通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VansonLanguageChanged" object:nil];
}

- (VLangCode)detectSystemLanguage {
    NSString *sysLang = [[NSLocale preferredLanguages] firstObject];
    
    if ([sysLang hasPrefix:@"zh-Hans"] || [sysLang hasPrefix:@"zh-CN"]) {
        return VLangCode::CN;
    } else if ([sysLang hasPrefix:@"zh-Hant"] || [sysLang hasPrefix:@"zh-TW"] || [sysLang hasPrefix:@"zh-HK"]) {
        return VLangCode::TW;
    } else if ([sysLang hasPrefix:@"ja"]) {
        return VLangCode::JA;
    } else if ([sysLang hasPrefix:@"ko"]) {
        return VLangCode::KO;
    } else if ([sysLang hasPrefix:@"ru"]) {
        return VLangCode::RU;
    } else if ([sysLang hasPrefix:@"es"]) {
        return VLangCode::ES;
    } else if ([sysLang hasPrefix:@"vi"]) {
        return VLangCode::VI;
    } else if ([sysLang hasPrefix:@"th"]) {
        return VLangCode::TH;
    } else if ([sysLang hasPrefix:@"pt"]) {
        return VLangCode::PT;
    } else if ([sysLang hasPrefix:@"fr"]) {
        return VLangCode::FR;
    } else if ([sysLang hasPrefix:@"de"]) {
        return VLangCode::DE;
    } else if ([sysLang hasPrefix:@"ar"]) {
        return VLangCode::AR;
    }
    
    return VLangCode::EN;
}

- (NSInteger)currentLanguage {
    return _cachedLangIndex >= 0 ? _cachedLangIndex : [[NSUserDefaults standardUserDefaults] integerForKey:kLangKey];
}

// 获取所有支持的语言列表 (用于 UI 显示)
- (NSArray<NSDictionary *> *)supportedLanguages {
    return @[
        @{@"code": @"auto", @"name": @"Auto", @"native": @"Auto"},
        @{@"code": @"en", @"name": @"English", @"native": @"English"},
        @{@"code": @"zh-Hans", @"name": @"Simplified Chinese", @"native": @"简体中文"},
        @{@"code": @"zh-Hant", @"name": @"Traditional Chinese", @"native": @"繁體中文"},
        @{@"code": @"ja", @"name": @"Japanese", @"native": @"日本語"},
        @{@"code": @"ko", @"name": @"Korean", @"native": @"한국어"},
        @{@"code": @"ru", @"name": @"Russian", @"native": @"Русский"},
        @{@"code": @"es", @"name": @"Spanish", @"native": @"Español"},
        @{@"code": @"vi", @"name": @"Vietnamese", @"native": @"Tiếng Việt"},
        @{@"code": @"th", @"name": @"Thai", @"native": @"ไทย"},
        @{@"code": @"pt", @"name": @"Portuguese", @"native": @"Português"},
        @{@"code": @"fr", @"name": @"French", @"native": @"Français"},
        @{@"code": @"de", @"name": @"German", @"native": @"Deutsch"},
        @{@"code": @"ar", @"name": @"Arabic", @"native": @"العربية"},
    ];
}

// 获取当前语言的本地名称
- (NSString *)currentLanguageName {
    NSInteger idx = [self currentLanguage];
    NSArray *langs = [self supportedLanguages];
    if (idx >= 0 && idx < langs.count) {
        return langs[idx][@"native"];
    }
    return @"Auto";
}

@end
