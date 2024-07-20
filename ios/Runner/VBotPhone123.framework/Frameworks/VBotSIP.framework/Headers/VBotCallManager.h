//
//  VBotCallManager.h
//  Copyright © 2016 Devhouse Spindle. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import "VBotAudioController.h"

@class VBotCall;
@class VBotAccount;

/**
 *  The VBotCallManager class is the single point of entry for everything you want to do with a call.
 *  - start an outbound call
 *  - end a call
 *  - mute or hold a call
 *  - sent DTMF signals
 *
 *  It takes care the CallKit (if available) and PJSIP interactions.
 */
@interface VBotCallManager : NSObject

/**
 *  Controler responsible for managing the audio streams for the calls.
 */
@property (readonly) VBotAudioController * _Nonnull audioController;

/**
 *  Start a call to the given number for the given account.
 *
 *  @param number The number to call.
 *  @param account The account to use for the call
 *  @param completion A completion block which is always invoked. Either the call is started successfully and you can obtain an
 *  VBotCall instance throught the block or, when the call fails, you can query the blocks error parameter.
 */
- (void)startCallToNumber:(NSString * _Nonnull)number forAccount:(VBotAccount * _Nonnull)account completion:(void (^_Nonnull )(VBotCall * _Nullable call, NSError * _Nullable error))completion;

/**
 *  Answers the given inbound call.
 *
 *  #param completion A completion block giving access to an NSError when unable to answer the given call.
 */
- (void)answerCall:(VBotCall * _Nonnull)call completion:(void (^ _Nonnull)(NSError * _Nullable error))completion;

/**
 *  End the given call.
 *
 *  @param call The VBotCall instance to end.
 *  @param completion A completion block giving access to an NSError when the given call could not be ended.
 */
- (void)endCall:(VBotCall * _Nonnull)call completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

/**
 *  Toggle mute of the microphone for this call.
 *
 *  @param completion A completion block giving access to an NSError when mute cannot be toggle for the given call.
 */
- (void)toggleMuteForCall:(VBotCall * _Nonnull)call completion:(void (^ _Nonnull)(NSError * _Nullable error))completion;

/**
 *  Toggle hold of the call.
 *
 *  @param completion A completion block giving access to an NSError when the given call cannot be put on hold.
 */
- (void)toggleHoldForCall:(VBotCall * _Nonnull)call completion:(void (^ _Nonnull)(NSError * _Nullable error))completion;

/**
 *  Send DTMF tone for this call with a character.
 *
 *  @param character character NSString the character for the DTMF.
 *  @param completion A completion block giving access to an NSError when sending DTMF fails.
 */
- (void)sendDTMFForCall:(VBotCall * _Nonnull)call character:(NSString * _Nonnull)character completion:(void (^ _Nonnull)(NSError * _Nullable error))completion;

/**
 *  Find a call with the given UUID.
 *
 *  @param uuid The UUID of the call to find.
 *
 *  @return A VBotCall instance if a call was found for the given UUID, otherwise nil.
 */
- (VBotCall * _Nullable)callWithUUID:(NSUUID * _Nonnull)uuid;

/**
 *  Find a call for the given call ID.
 *
 *  @param callId The PJSIP generated call ID given to an incoming call.
 *
 *  @return A VBotCall instance if a call with the given call ID was found, otherwise nil.
 */
- (VBotCall * _Nullable)callWithCallId:(NSInteger)callId;

/**
 *  Returns all the calls for a given account.
 *
 * @param account The VBotAccount for which to find it's calls.
 *
 * @return An NSArray containing all the accounts calls or nil.
 */
- (NSArray * _Nullable)callsForAccount:(VBotAccount * _Nonnull)account;

/**
 *  Add the given call to the Call Manager.
 *
 *  @param call The VBotCall instance to add.
 */
- (void)addCall:(VBotCall * _Nonnull)call;

/**
 *  Remove the given call from the Call Manager.
 *
 *  @param call the VBotCall instance to remove.
 */
- (void)removeCall:(VBotCall * _Nonnull)call;

/**
 *  End all calls.
 */
- (void)endAllCalls;

/**
 *  End all calls for the given account.
 *
 *  @param account The VBotAccount instance for which to end all calls.
 */
- (void)endAllCallsForAccount:(VBotAccount * _Nonnull)account;

/**
 *  Returns the first call for the given account
 *
 *  @param account The VBotAccount instance for which to return the first call.
 *
 *  @return The first call for the given account, otherwise nil.
 */
- (VBotCall * _Nullable)firstCallForAccount:(VBotAccount * _Nonnull)account;

/**
 *  Returns the first ACTIVE call for the given account.
 *
 *  @param account The VBotAccount instance for which to return the first active call.
 *
 *  @return The first active call for the given account, otherwise nil.
 */
- (VBotCall * _Nullable)firstActiveCallForAccount:(VBotAccount * _Nonnull)account;

/**
 *  Returns the last call for the given account
 *
 *  @param account The VBotAccount instance for which to return the last call.
 *
 *  @return The last call for the given account, otherwise nil.
 */
- (VBotCall * _Nullable)lastCallForAccount:(VBotAccount * _Nonnull)account;

/**
 *  Reinvite all active calls for the given account.
 *
 *  @param account The VBotAccount instance for which to reinvite all calls.
 */
- (void)reinviteActiveCallsForAccount:(VBotAccount * _Nonnull)account;

/**
 *  Sent a SIP UPDATE message to all active calls for the given account.
 *
 *  @param account The VBotAccount instance for which to sent the UPDATE.
 */
- (void)updateActiveCallsForAccount:(VBotAccount * _Nonnull)account;
@end
