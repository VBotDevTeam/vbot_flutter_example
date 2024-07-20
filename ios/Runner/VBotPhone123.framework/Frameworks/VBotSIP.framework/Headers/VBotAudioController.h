//
//  VBotAudioController.h
//  Copyright © 2015 Devhouse Spindle. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * __nonnull const VBotAudioControllerAudioInterrupted;
extern NSString * __nonnull const VBotAudioControllerAudioResumed;

/**
 *  Possible outputs the audio can have.
 */
typedef NS_ENUM(NSInteger, VBotAudioControllerOutputs) {
    /**
     *  Audio is sent over the speaker
     */
    VBotAudioControllerOutputSpeaker,
    /**
     *  Audio is sent to the ear speaker or mini jack
     */
    VBotAudioControllerOutputOther,
    /**
     *  Audio is sent to bluetooth
     */
    VBotAudioControllerOutputBluetooth,
};
#define VBotAudioControllerOutputsString(VBotAudioControllerOutputs) [@[@"VBotAudioControllerOutputSpeaker", @"VBotAudioControllerOutputOther", @"VBotAudioControllerOutputBluetooth"] objectAtIndex:VBotAudioControllerOutputs]


@interface VBotAudioController : NSObject

/**
 *  If there is a Bluetooth headset connected, this will return YES.
 */
@property (readonly, nonatomic) BOOL hasBluetooth;

/**
 *  The current routing of the audio.
 *
 *  Attention: Possible values that can be set: VBotAudioControllerSpeaker & VBotAudioControllerOther.
 *  Setting the property to VBotAudioControllerBluetooth won't work, if you want to activatie bluetooth
 *  you have to change the route with the mediaplayer (see example app).
 */
@property (nonatomic) VBotAudioControllerOutputs output;

/**
 *  Configure audio.
 */
- (void)configureAudioSession;

/**
 *  Activate the audio session.
 */
- (void)activateAudioSession;

/**
 *  Deactivate the audio session.
 */
- (void)deactivateAudioSession;

@end
