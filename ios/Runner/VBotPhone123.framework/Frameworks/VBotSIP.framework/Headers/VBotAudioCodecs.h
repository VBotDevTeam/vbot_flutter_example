//
//  VBotCodecs.h
//  Copyright © 2018 Devhouse Spindle. All rights reserved.
//


#import <Foundation/Foundation.h>

#import "VBotCodecConfiguration.h"

/**
 *  Enum of possible Audio Codecs.
 */
typedef NS_ENUM(NSInteger, VBotAudioCodec) {
        // G711a
    VBotAudioCodecG711a,
        // G722
    VBotAudioCodecG722,
        // iLBC
    VBotAudioCodecILBC,
        // G711
    VBotAudioCodecG711,
        // Speex 8 kHz
    VBotAudioCodecSpeex8000,
        // Speex 16 kHz
    VBotAudioCodecSpeex16000,
        // Speex 32 kHz
    VBotAudioCodecSpeex32000,
        // GSM 8 kHZ
    VBotAudioCodecGSM,
        // Opus
    VBotAudioCodecOpus,
};
#define VBotAudioCodecString(VBotAudioCodec) [VBotAudioCodecArray objectAtIndex:VBotAudioCodec]
#define VBotAudioCodecStringWithIndex(NSInteger) [VBotAudioCodecArray objectAtIndex:NSInteger]
#define VBotAudioCodecArray @[@"PCMA/8000/1", @"G722/16000/1", @"iLBC/8000/1", @"PCMU/8000/1", @"speex/8000/1", @"speex/16000/1", @"speex/32000/1", @"GSM/8000/1", @"opus/48000/2"]


@interface VBotAudioCodecs : NSObject

/**
 *  The prioritiy of the codec
 */
@property (readonly, nonatomic) NSUInteger priority;

/**
 * The used codec.
 */
@property (readonly, nonatomic) VBotAudioCodec codec;

/**
 * Make the default init unavaibale.
 */
- (instancetype _Nonnull) init __attribute__((unavailable("init not available. Use initWithAudioCodec instead.")));

/**
 * The init to setup the audio codecs.
 *
 * @param codec     Audio codec codec to set the prioritiy for.
 * @param priority  NSUInteger the priority the codec will have.
 */
- (instancetype _Nonnull)initWithAudioCodec:(VBotAudioCodec)codec andPriority:(NSUInteger)priority;

/**
 * Get the codec from the #define VBotCodecConfigurationAudioString with a VBotCodecConfigurationAudio type.
 *
 * @param codec VBotCodecConfigurationAudio the codec to get the string representation of.
 *
 * @return NSString the string representation of the VBotCodecConfigurationAudio type.
 */
+ (NSString * _Nonnull)codecString:(VBotAudioCodec)codec;

/**
 * Get the codec from the defined VBotCodecConfigurationAudioString with an index.
 */
+ (NSString * _Nonnull)codecStringWithIndex:(NSInteger)index;

@end
