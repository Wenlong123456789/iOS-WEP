#import "VLCrypto.h"

@implementation VLCrypto

+ (uint32_t)getVM24Magic {
    return 0;
}

+ (BOOL)isVM24Format:(NSData *)data {
    if (!data || data.length == 0) return NO;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]];
}

+ (nullable NSData *)decryptVM24Data:(NSData *)data {
    return data ? [data copy] : nil;
}

+ (nullable NSData *)encryptToVM24Data:(NSData *)data {
    return data ? [data copy] : nil;
}

+ (nullable NSData *)dataFromHexString:(NSString *)hex {
    if (!hex) return nil;
    NSMutableData *data = [NSMutableData data];
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *clean = [[hex componentsSeparatedByCharactersInSet:ws] componentsJoinedByString:@""];
    for (NSUInteger i = 0; i + 1 < clean.length; i += 2) {
        NSString *byteString = [clean substringWithRange:NSMakeRange(i, 2)];
        unsigned int byte = 0;
        if ([[NSScanner scannerWithString:byteString] scanHexInt:&byte]) {
            uint8_t b = (uint8_t)byte;
            [data appendBytes:&b length:1];
        }
    }
    return data.length > 0 ? data : nil;
}

+ (NSString *)hexStringFromData:(NSData *)data {
    if (!data || data.length == 0) return @"";
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) {
        [hex appendFormat:@"%02X", bytes[i]];
    }
    return hex;
}

@end
