/**
 * VansonLoader L2.3 - 多语言支持
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 快捷宏
#define VL(key) [[VLLocalization shared] localizedString:key]

@interface VLLocalization : NSObject

+ (instancetype)shared;

// 获取本地化字符串
- (NSString *)localizedString:(NSString *)key;

// 设置语言 (0=Auto, 1=EN, 2=CN, 3=TW, 4=JA, 5=KO, 6=RU, 7=ES, 8=VI, 9=TH, 10=PT, 11=FR, 12=DE, 13=AR)
- (void)setLanguage:(NSInteger)langIndex;

// 获取当前语言索引
- (NSInteger)currentLanguage;

// 获取所有支持的语言列表
- (NSArray<NSDictionary *> *)supportedLanguages;

// 获取当前语言的本地名称
- (NSString *)currentLanguageName;

@end

// 兼容别名
typedef VLLocalization VLocalization;

NS_ASSUME_NONNULL_END
