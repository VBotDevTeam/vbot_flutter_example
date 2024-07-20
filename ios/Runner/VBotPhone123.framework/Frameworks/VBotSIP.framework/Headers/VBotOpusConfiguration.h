//
//  VBotOpusConfiguration.h
//  Copyright © 2018 Devhouse Spindle. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, VBotOpusConfigurationSampleRate) {
    VBotOpusConfigurationSampleRateFullBand = 48000,
    VBotOpusConfigurationSampleRateSuperWideBand = 24000,
    VBotOpusConfigurationSampleRateWideBand = 16000,
    VBotOpusConfigurationSampleRateMediumBand = 12000,
    VBotOpusConfigurationSampleRateNarrowBand = 8000
};

typedef NS_ENUM(NSUInteger, VBotOpusConfigurationFrameDuration) {
    VBotOpusConfigurationFrameDurationFive = 5,
    VBotOpusConfigurationFrameDurationTen = 10,
    VBotOpusConfigurationFrameDurationTwenty = 20,
    VBotOpusConfigurationFrameDurationForty = 40,
    VBotOpusConfigurationFrameDurationSixty = 60
};

/**
 *  OPUS configuration for more explanation read the RFC at https://tools.ietf.org/html/rfc6716
 */
@interface VBotOpusConfiguration : NSObject

/**
 * Sample rate in Hz
 *
 *  Default: VBotOpusConfigurationSampleRateFullBand (48000 hz)
 */
@property (nonatomic) VBotOpusConfigurationSampleRate sampleRate;

/**
 *  The frame size of the packets being sent over.
 *
 *  Default: VBotOpusConfigurationFrameDurationSixty (60 msec)
 */
@property (nonatomic) VBotOpusConfigurationFrameDuration frameDuration;

/**
 *  Encoder complexity, 0-10 (10 is highest) 
 *
 *  Default: 5
 */
@property (nonatomic) NSUInteger complexity;

/**
 *  YES for Constant bitrate (CBR) and no to use Variable bitrate (VBR)
 *
 *  Set to YES for:
 *      - When the transport only supports a fixed size for each compressed frame, or
 *      - When encryption is used for an audio stream that is either highly constrained (e.g., yes/no, recorded prompts) or highly sensitive
 *
 *  Default: NO
 */
@property (nonatomic) BOOL constantBitRate;

@end
