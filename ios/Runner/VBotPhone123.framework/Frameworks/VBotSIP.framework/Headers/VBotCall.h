//
//  VBotCall.h
//  Copyright © 2015 Devhouse Spindle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VBotAccount.h"
#import "VBotCallStats.h"
#import <VialerPJSIP/pjsua.h>
#import "SipInvite.h"

/**
 *  Notification which is posted when the call's state changes.
 *  The call for which the state changed can be found in the
 *  notifications user info dict.
 */
extern NSString * _Nonnull const VBotCallStateChangedNotification;

/**
 *  Notification which is posted when the call's media event recived.
 *  The callId for which the media event changed can be found in the
 *  notifications user info dict.
 */
extern NSString * _Nonnull const VBotNotificationUserInfoVideoSizeRenderKey;

/**
 *  Notification for when the VBotCall object has been dealloced.
 */
extern NSString * _Nonnull const VBotCallDeallocNotification;

/**
 *  Notification for when there is no audio during a call.
 */
extern NSString * _Nonnull const VBotCallNoAudioForCallNotification;

/**
 * Notification for when there is an error setting up a call.
 */
extern NSString * _Nonnull const VBotCallErrorDuringSetupCallNotification;

/**
 *  Notification that will be posted when a phonecall is connected.
 */
extern NSString * _Nonnull const VBotCallConnectedNotification DEPRECATED_MSG_ATTRIBUTE("Deprecated, listen for VBotCallStateChangedNotification instead");

/**
 *  Notification that will be posted when a phonecall is disconnected locally.
 */
extern NSString * _Nonnull const VBotCallDisconnectedNotification DEPRECATED_MSG_ATTRIBUTE("Deprecated, listen for VBotCallStateChangedNotification instead");

/**
 *  The posible errors VBotCall can return.
 */
typedef NS_ENUM(NSInteger, VBotCallErrors) {
    /**
     *  Unable to create a PJSip thread.
     */
    VBotCallErrorCannotCreateThread,
    /**
     *  Unable to create call.
     */
    VBotCallErrorCannotCreateCall,
    /**
     *  Unable to answer an incoming call.
     */
    VBotCallErrorCannotAnswerCall,
    /**
     *  Unable to hangup call.
     */
    VBotCallErrorCannotHangupCall,
    /**
     *  Unable to decline call.
     */
    VBotCallErrorCannotDeclineCall,
    /**
     *  Unable to toggle mute call.
     */
    VBotCallErrorCannotToggleMute,
    /**
     *  Unable to toggle hold call.
     */
    VBotCallErrorCannotToggleHold,
    /**
     *  Unable to send DTMF for call.
     */
    VBotCallErrorCannotSendDTMF,
};
#define VBotCallErrorsString(VBotCallErrors) [@[@"VBotCallErrorCannotCreateThread", @"VBotCallErrorCannotCreateCall", @"VBotCallErrorCannotAnswerCall", @"VBotCallErrorCannotHangupCall", @"VBotCallErrorCannotDeclineCall", @"VBotCallErrorCannotToggleMute", @"VBotCallErrorCannotToggleHold", @"VBotCallErrorCannotSendDTMF"] objectAtIndex:VBotCallErrors]


/**
 *  The states which a call can have.
 */
typedef NS_ENUM(NSInteger, VBotCallState) {
    /**
     *   Before INVITE is sent or received.
     */
    VBotCallStateNull = PJSIP_INV_STATE_NULL,
    /**
     *   After INVITE is sent.
     */
    VBotCallStateCalling = PJSIP_INV_STATE_CALLING,
    /**
     *  After INVITE is received.
     */
    VBotCallStateIncoming = PJSIP_INV_STATE_INCOMING,
    /**
     *  After response with To tag.
     */
    VBotCallStateEarly = PJSIP_INV_STATE_EARLY,
    /**
     *  After 2xx is sent/received.
     */
    VBotCallStateConnecting = PJSIP_INV_STATE_CONNECTING,
    /**
     *  After ACK is sent/received.
     */
    VBotCallStateConfirmed = PJSIP_INV_STATE_CONFIRMED,
    /**
     *  Session is terminated.
     */
    VBotCallStateDisconnected = PJSIP_INV_STATE_DISCONNECTED,
};
#define VBotCallStateString(VBotCallState) [@[@"VBotCallStateNull", @"VBotCallStateCalling", @"VBotCallStateIncoming", @"VBotCallStateEarly", @"VBotCallStateConnecting", @"VBotCallStateConfirmed", @"VBotCallStateDisconnected"] objectAtIndex:VBotCallState]


/**
 *  The states which the media can have.
 */
typedef NS_ENUM(NSInteger, VBotMediaState) {
    /**
     *  There is no media.
     */
    VBotMediaStateNone = PJSUA_CALL_MEDIA_NONE,
    /**
     *  The media is active.
     */
    VBotMediaStateActive = PJSUA_CALL_MEDIA_ACTIVE,
    /**
     *  The media is locally on hold.
     */
    VBotMediaStateLocalHold = PJSUA_CALL_MEDIA_LOCAL_HOLD,
    /**
     *  The media is remote on hold.
     */
    VBotMediaStateRemoteHold = PJSUA_CALL_MEDIA_REMOTE_HOLD,
    /**
     *  There is an error with the media.
     */
    VBotMediaStateError = PJSUA_CALL_MEDIA_ERROR,
};
#define VBotMediaStateString(VBotMediaState) [@[@"VBotMediaStateNone", @"VBotMediaStateActive", @"VBotMediaStateLocalHold", @"VBotMediaStateRemoteHold", @"VBotMediaStateError"] objectAtIndex:VBotMediaState]

typedef NS_ENUM(NSInteger, VBotCallTransferState) {
    VBotCallTransferStateUnkown,
    VBotCallTransferStateInitialized,
    VBotCallTransferStateTrying,
    VBotCallTransferStateAccepted,
    VBotCallTransferStateRejected,
};
#define VBotCallTransferStateString(VBotCallTransferState) [@[@"VBotCallTransferStateUnkown", @"VBotCallTransferStateInitialized", @"VBotCallTransferStateTrying", @"VBotCallTransferStateAccepted", @"VBotCallTransferStateRejected"] objectAtIndex:VBotCallTransferState]

typedef NS_ENUM(NSInteger, VBotCallAudioState) {
    /**
     *  There is audio for the call.
     */
    VBotCallAudioStateOK,
    /**
     *  There hasn't been any audio received during the call.
     */
    VBotCallAudioStateNoAudioReceiving,
    /**
     *  There wasn't any audio transmitted.
     */
    VBotCallAudioStateNoAudioTransmitting,
    /**
     *  There wasn't any audio in both directions.
     */
    VBotCallAudioStateNoAudioBothDirections,
};
#define VBotCallAudioStateString(VBotCallAudioState) [@[@"VBotCallAudioStateOK", @"VBotCallAudioStateNoAudioReceiving", @"VBotCallAudioStateNoAudioTransmitting", @"VBotCallAudioStateNoAudioBothDirections"] objectAtIndex:VBotCallAudioState]

typedef NS_ENUM(NSInteger, VBotCallTerminateReason) {
    VBotCallTerminateReasonUnknown,
    /**
     * Call has been picked up elsewhere.
     */
    VBotCallTerminateReasonCallCompletedElsewhere,
    /**
     * The caller has hung up before the call was picked up.
     */
    VBotCallTerminateReasonOriginatorCancel,
};
#define VBotCallTerminateReasonString(VBotCallTerminateReason) [@[@"VBotCallTerminateReasonUnknown", @"VBotCallTerminateReasonCallCompletedElsewhere", @"VBotCallTerminateReasonOriginatorCancel"] objectAtIndex:VBotCallTerminateReason]


@interface VBotCall : NSObject

#pragma mark - Properties

/**
 *  The callId which a call receives from PJSIP when it is created.
 */
@property (nonatomic) NSInteger callId;

/**
 * The Call-ID that is present in the SIP messages.
 */
@property (readonly, nonatomic) NSString * _Nonnull messageCallId;

/**
 *  All created calls get an unique ID.
 */
@property (readonly, nonatomic) NSUUID * _Nonnull uuid;

/**
 *  The VBotAccount the call belongs to.
 */
@property (weak, nonatomic) VBotAccount * _Nullable account;

/**
 *  The state in which the call currently has.
 */
@property (readonly, nonatomic) VBotCallState callState;

/**
 *  There state in which the audio is for the call.
 */
@property (readonly, nonatomic) VBotCallAudioState callAudioState;

/**
 *  The state text which the call currently has.
 */
@property (readonly, nonatomic) NSString * _Nullable callStateText;

/**
 *  The last status code the call had.
 */
@property (readonly, nonatomic) NSInteger lastStatus;

/**
 *  The last status text the call had.
 */
@property (readonly, nonatomic) NSString * _Nullable lastStatusText;

/**
 *  The state in which the media of the call currently is.
 */
@property (readonly, nonatomic) VBotMediaState mediaState;

/**
 *  The local URI of the call.
 */
@property (readonly, nonatomic) NSString * _Nullable localURI;

/**
 *  The remote URI of the call.
 */
@property (readonly, nonatomic) NSString * _Nullable remoteURI;

/**
 *  The name of the caller.
 */
@property (readonly, nonatomic) NSString * _Nullable callerName;

/**
 *  The number of the caller.
 */
@property (readonly, nonatomic) NSString * _Nullable callerNumber;

/**
 *  True if the call was incoming.
 */
@property (readonly, getter=isIncoming) BOOL incoming;

/**
 *  True if the microphone is muted.
 */
@property (readonly, nonatomic) BOOL muted;

/**
 *  True if the call is on hold locally.
 */
@property (readonly, nonatomic) BOOL onHold;

/**
 *  The statie in which the transfer of the call currently is.
 */
@property (readonly, nonatomic) VBotCallTransferState transferStatus;

/*
 * The reason why a call was termianted.
 */
@property (nonatomic) VBotCallTerminateReason terminateReason;

/**
 *  For an outbound call, this property is set and indicates the number
 *  that will be called/dialed when -startWithCompletion is invoked.
 */
@property (readonly, strong) NSString * _Nonnull numberToCall;

/*
 * Property is true when the call was hungup locally.
 */
@property (readonly) BOOL userDidHangUp;

@property (readonly) BOOL connected;

@property (readwrite, nonatomic) SipInvite * _Nullable invite;

#pragma mark - Stats

/**
 *  Calculated amount of data transferred (Receiving & Transmitting).
 */
@property (readonly, nonatomic) float totalMBsUsed;

/**
 *  The connection duration of the call.
 */
@property (readonly, nonatomic) NSTimeInterval connectDuration;

/**
 *  Calculated MOS score of the call.
 *
 *  Based on Mean Opinion Score for calls, see: https://en.wikipedia.org/wiki/Mean_opinion_score
 *  Ranges from 1 to 4.4 (slighty different than on wiki). Translates to:
 *
 *  MOS     Quality     Impairment
 *  5       Excellent	Imperceptible
 *  4       Good        Perceptible but not annoying
 *  3       Fair        Slightly annoying
 *  2       Poor        Annoying
 *  1       Bad         Very annoying
 */
@property (readonly, nonatomic) float MOS;

/**
 * The codec that has been used during the call.
 */
@property (readonly, nonatomic) NSString * _Nonnull activeCodec;

#pragma mark - Methods

/**
 *  Calculate MOS score & data use of call.
 */
- (void)calculateStats;

/**
 * This init is not available.
 */
-  (instancetype _Nonnull)init __attribute__((unavailable("Init is not available")));

/**
 *  Deprecated function. You should init an outbound call using -initOutboundCallWithNumberToCall
 *  and start the call using -startWithCompletion.
 *
 *  This will setup a call to the given number and attached to the account.
 *
 *  @param number  The number that should be called.
 *  @param account The account to which the call should be added.
 *  @param error   Pointer to an NSError pointer. Will be set to a NSError instance if cannot setup the call.
 *
 *  @return VBotCall instance
 */
+ (instancetype _Nullable)callNumber:(NSString * _Nonnull)number withAccount:(VBotAccount * _Nonnull)account error:(NSError * _Nullable * _Nullable)error __attribute__((unavailable("Deprecated, use -startWithCompletion instead")));

/**
 *  When PJSIP receives an incoming call, this initializer is called.
 *
 *  @param callId The call ID generated by PJSIP.
 *
 *  @return VBotCall instance
 */
- (instancetype _Nullable)initInboundCallWithCallId:(NSUInteger)callId account:(VBotAccount * _Nonnull)account;

/**
 *  When PJSIP receives an incoming call, this initializer is called.
 *
 *  @param callId The call ID generated by PJSIP.
 *  @param account The account being used to call.
 *  @param invite An instance of SipInvite that has been created using the INVITE packet.
 *  @return VBotCall instance
 */
- (instancetype _Nullable)initInboundCallWithCallId:(NSUInteger)callId account:(VBotAccount * _Nonnull)account andInvite:(SipInvite *_Nonnull)invite;

/**
*  When VBot receives a push message reporting an incoming call, this initializer is called.
*
*  @param uuid The call uuid taken from the push message.
*  @param number The number from the caller taken from the push message.
*  @param name The name from the caller taken from the push message.
*  @return VBotCall instance
*/
- (instancetype _Nullable)initInboundCallWithUUID:(NSUUID * _Nonnull)uuid number:(NSString * _Nonnull)number name:(NSString * _Nonnull)name;

- (instancetype _Nullable)initWithCallId:(NSUInteger)callId accountId:(NSInteger)accountId __attribute__((unavailable("Deprecated, use -initWithCallID: andAccount: instead")));

/*
 *  Init an outbound call.
 *
 *  @param number The number to call (when invoking -startWithCompletion).
 *  @param account The VBotAccount for which this call is created.
 *
 *  @return VBotCall instance.
 */
- (instancetype _Nullable)initOutboundCallWithNumberToCall:(NSString * _Nonnull)number account:(VBotAccount * _Nonnull)account;

/**
 *  This will change the callState of the call.
 *
 *  @param callInfo pjsip callInfo
 */
- (void)callStateChanged:(pjsua_call_info)callInfo;

/**
 *  This will change the mediaState of the call.
 *
 *  @param callInfo pjsip callInfo
 */
- (void)mediaStateChanged:(pjsua_call_info)callInfo;

/**
 *  Start the call. The number that will be called is the number provided when the call was created using
 *  -initWithNumbertoCall
 *
 *  @param completion A completion block called when the call is started. The block has an error
 *  parameter which contains an error when the outbound call fails, otherwise Nil.
 */
- (void)startWithCompletion:(void (^ _Nonnull)(NSError * _Nullable error))completion;

/**
 *  This will end the call.
 *
 *  @param error Pointer to an NSError pointer. Will be set to a NSError instance if cannot hangup the call.
 *
 *  @return BOOL success of hanging up the call.
 */
- (BOOL)hangup:(NSError * _Nullable * _Nullable)error;

/**
 *  This will decline the incoming call.
 *
 *  @param error Pointer to an NSError pointer. Will be set to a NSError instance if cannot decline the call.
 *
 *  @return BOOL success of declining up the call.
 */
- (BOOL)decline:(NSError * _Nullable * _Nullable)error;

/**
 *  Toggle mute of the microphone for this call.
 *
 *  @param error Pointer to an NSError pointer. Will be set to a NSError instance if cannot toggle mute of the call.
 */
- (BOOL)toggleMute:(NSError * _Nullable * _Nullable)error;

/**
 *  This will answer the incoming call.
 *
 *  @param completion A completion block called when sucessfully answering the call. The block has an error
 *  parameter which contains an error when answering the call fails, otherwise Nil.
 *
 *  @warning Do not user this function directly, user VBotCallManager -anserCall: completion: otherwise the
 *  audio session is not activated.
 */
- (void)answerWithCompletion:(void (^ _Nullable)(NSError * _Nullable error))completion;
- (BOOL)answer:(NSError * _Nullable * _Nullable)error __attribute__((unavailable("Deprecated, use VBotCallManager -answerCall: completion: instead")));

/**
 *  Toggle hold of the call.
 *
 *  @param error Pointer to an NSError pointer. Will be set to a NSError instance if cannot put call on hold.
 */
- (BOOL)toggleHold:(NSError * _Nullable * _Nullable)error;

/**
 *  Send DTMF tone for this call with a character.
 *
 *  @param character character NSString the character for the DTMF.
 *  @param error     error Pointer to an NSError pointer. Will be set to a NSError instance if cannot send DTMF for the call.
 */
- (BOOL)sendDTMF:(NSString * _Nonnull)character error:(NSError * _Nullable * _Nullable)error;

/**
 *  Blind transfer a call with a given number.
 *
 *  @param number NSString the number that should be transfered to.
 *
 *  @return BOOL success if the transfer has been sent.
 */
- (BOOL)blindTransferCallWithNumber:(NSString * _Nonnull)number;

/**
 *  Transfer the call to the given VBotCall.
 *
 *  @param secondCall VBotCall this call should be transferred to.
 *
 *  @return BOOL success of the call transfer.
 */
- (BOOL)transferToCall:(VBotCall * _Nonnull)secondCall;

/**
 *  This will change the transferStatus of the call.
 *
 *  @param statusCode The status code of the transfer state.
 *  @param text The description of the transfer state.
 *  @param final BOOL indictating this is the last update of the transfer state.
 */
- (void)callTransferStatusChangedWithStatusCode:(NSInteger)statusCode statusText:(NSString * _Nullable)text final:(BOOL)final;

/**
 *  Will re-invite call.
 */
- (void)reinvite;

/**
 *  Will sent the UPDATE message to the call.
 */
- (void)update;

+ (NSDictionary *)getCallerInfoFromRemoteUri:(NSString *)string;
@end
