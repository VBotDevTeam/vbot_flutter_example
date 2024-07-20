//
//  VBotVideoCodecs.h
//  VBotSIP
//
//  Created by Redmer Loen on 4/5/18.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, VBotVideoCodec) {
        // H264
    VBotVideoCodecH264
};
#define VBotVideoCodecString(VBotVideoCodec) [VBotVideoCodecArray objectAtIndex:VBotVideoCodec]
#define VBotVideoCodecStringWithIndex(NSInteger) [VBotVideoCodecArray objectAtIndex:NSInteger]
#define VBotVideoCodecArray @[@"H264/97"]


@interface VBotVideoCodecs : NSObject

/**
 *  The prioritiy of the codec
 */
@property (readonly, nonatomic) NSUInteger priority;

/**
 * The used codec.
 */
@property (readonly, nonatomic) VBotVideoCodec codec;

/**
 * Make the default init unavaibale.
 */
- (instancetype _Nonnull) init __attribute__((unavailable("init not available. Use initWithVideoCodec instead.")));

/**
 * The init to setup the video codecs.
 *
 * @param codec     Audio codec codec to set the prioritiy for.
 * @param priority  NSUInteger the priority the codec will have.
 */
- (instancetype _Nonnull)initWithVideoCodec:(VBotVideoCodec)codec andPriority:(NSUInteger)priority;

/**
 * Get the codec from the #define VBotVideoCodecString with a VBotVideoCodec type.
 *
 * @param codec VBotVideoCodec the codec to get the string representation of.
 *
 * @return NSString the string representation of the VBotVideoCodec type.
 */
+ (NSString * _Nonnull)codecString:(VBotVideoCodec)codec;

/**
 * Get the codec from the defined VBotVideoCodecString with an index.
 */
+ (NSString * _Nonnull)codecStringWithIndex:(NSInteger)index;

@end
