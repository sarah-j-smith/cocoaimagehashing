//
//  OSCategories.m
//  CocoaImageHashing
//
//  Created by Andreas Meingast on 11/10/15.
//  Copyright © 2015 Andreas Meingast. All rights reserved.
//

#import "OSCategories.h"
#import "OSTypes.h"

#pragma mark - NSArray Category

@implementation NSArray (CocoaImageHashing)

- (NSArray<OSTuple<id, id> *> *)arrayWithPairCombinations
{
    NSArray<OSTuple<id, id> *> *result = [self arrayWithPairCombinations:^BOOL(id __unsafe_unretained leftHand, id __unsafe_unretained rightHand) {
      OS_MARK_UNUSED(leftHand);
      OS_MARK_UNUSED(rightHand);
      return YES;
    }];
    return result;
}

- (NSArray<OSTuple<id, id> *> *)arrayWithPairCombinations:(BOOL (^)(id __unsafe_unretained leftHand, id __unsafe_unretained rightHand))matcher
{
    NSMutableArray<OSTuple<id, id> *> *pairs = [NSMutableArray new];
    [self arrayWithPairCombinations:matcher
                  withResultHandler:^(id __unsafe_unretained leftHand, id __unsafe_unretained rightHand) {
                    OSTuple<id, id> *tuple = [OSTuple tupleWithFirst:leftHand
                                                           andSecond:rightHand];
                    [pairs addObject:tuple];
                  }];
    return pairs;
}

- (void)arrayWithPairCombinations:(BOOL (^)(id __unsafe_unretained leftHand, id __unsafe_unretained rightHand))matcher
                withResultHandler:(void (^)(id __unsafe_unretained leftHand, id __unsafe_unretained rightHand))resultHandler
{
    NSUInteger count = [self count];
    for (NSUInteger i = 0; i < count - 1; i++) {
        id __unsafe_unretained left = self[i];
        for (NSUInteger j = i + 1; j < count; j++) {
            id __unsafe_unretained right = self[j];
            BOOL result = matcher(left, right);
            if (result) {
                resultHandler(left, right);
            }
        }
    }
}

@end

#pragma mark - NSData Category

OS_INLINE OS_ALWAYS_INLINE NSUInteger OSBytesPerRowForWidth(NSUInteger width)
{
    return (width == 8) ? 32 : OS_ALIGN(4 * width, 64);
}

#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

@implementation NSData (CocoaImageHashing)

- (NSData *)RGBABitmapDataForResizedImageWithWidth:(NSUInteger)width
                                         andHeight:(NSUInteger)height
{
    UIImage *baseImage = [UIImage imageWithData:self];
    if (!baseImage) {
        return nil;
    }
    CGImageRef imageRef = [baseImage CGImage];
    if (!imageRef) {
        return nil;
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSUInteger bytesPerRow = OSBytesPerRowForWidth(width);
    NSUInteger bitsPerComponent = 8;
    NSMutableData *data = [NSMutableData dataWithLength:height * bytesPerRow];
    CGContextRef context = CGBitmapContextCreate([data mutableBytes], width, height, bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGRect rect = CGRectMake(0, 0, width, height);
    CGContextDrawImage(context, rect, imageRef);
    CGContextRelease(context);
    return data;
}

@end

#else

@implementation NSData (CocoaImageHashing)

- (NSData *)RGBABitmapDataForResizedImageWithWidth:(NSUInteger)width
                                         andHeight:(NSUInteger)height
{
    NSBitmapImageRep *sourceImageRep = [NSBitmapImageRep imageRepWithData:self];
    if (!sourceImageRep) {
        return nil;
    }
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepFrom:sourceImageRep
                                                  scaledToWidth:width
                                                 scaledToHeight:height
                                             usingInterpolation:NSImageInterpolationHigh];
    if (!imageRep) {
        return nil;
    }
    unsigned char *pixels = [imageRep bitmapData];
    NSData *result = [NSData dataWithBytes:pixels
                                    length:OSBytesPerRowForWidth(width) * height];
    return result;
}

@end

#endif

#pragma mark - NSBitmapImageRep Category

#if !(TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

@implementation NSBitmapImageRep (CocoaImageHashing)

+ (NSBitmapImageRep *)imageRepFrom:(NSBitmapImageRep *)sourceImageRep
                     scaledToWidth:(NSUInteger)width
                    scaledToHeight:(NSUInteger)height
                usingInterpolation:(NSImageInterpolation)imageInterpolation
{
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                         pixelsWide:(NSInteger)width
                                                                         pixelsHigh:(NSInteger)height
                                                                      bitsPerSample:8
                                                                    samplesPerPixel:4
                                                                           hasAlpha:YES
                                                                           isPlanar:NO
                                                                     colorSpaceName:NSCalibratedRGBColorSpace
                                                                        bytesPerRow:(NSInteger)OSBytesPerRowForWidth(width)
                                                                       bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
    context.imageInterpolation = imageInterpolation;
    [NSGraphicsContext setCurrentContext:context];
    [sourceImageRep drawInRect:NSMakeRect(0, 0, width, height)];
    [context flushGraphics];
    [NSGraphicsContext restoreGraphicsState];
    [imageRep setSize:NSMakeSize(width, height)];
    return imageRep;
}

@end

#endif

#pragma mark - NSImage Category

#if !(TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

@implementation NSImage (CocoaImageHashing)

- (NSData *)dataRepresentation
{
    NSData *result = [self TIFFRepresentation];
    return result;
}

@end

#endif

#pragma mark - UIImage Category

#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

@implementation UIImage (CocoaImageHashing)

- (NSData *)dataRepresentation
{
    NSData *result = UIImagePNGRepresentation(self);
    return result;
}

@end

#endif

#pragma mark - NSString Category

@implementation NSString (CocoaImageHashing)

- (unsigned long long)fileSizeOfElementInBundle:(NSBundle *)bundle
{
    NSString *path = [bundle pathForResource:[self stringByDeletingPathExtension]
                                      ofType:[self pathExtension]];
    NSDictionary<NSString *, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path
                                                                                                error:nil];
    NSNumber *fileSizeNumber = attributes[@"NSFileSize"];
    unsigned long long result = [fileSizeNumber unsignedLongLongValue];
    return result;
}

@end
