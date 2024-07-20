//
//  VBotCodecConfiguration.h
//  Copyright © 2018 Devhouse Spindle. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "VBotAudioCodecs.h"
#import "VBotVideoCodecs.h"
#import "VBotOpusConfiguration.h"

@interface VBotCodecConfiguration : NSObject

/**
 * An array of available audio codecs.
 */
@property (strong, nonatomic) NSArray * _Nullable audioCodecs;

/**
 * An array of available video codecs.
 */
@property (strong, nonatomic) NSArray * _Nullable videoCodecs;

/**
 *  The linked OPUS configuration when opus is being used.
 */
@property (nonatomic) VBotOpusConfiguration * _Nullable opusConfiguration;

@end
