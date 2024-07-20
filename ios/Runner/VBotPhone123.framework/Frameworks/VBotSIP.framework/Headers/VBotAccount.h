//
//  VBotAccount.h
//  Copyright © 2015 Devhouse Spindle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VBotAccountConfiguration.h"

@class VBotCall, VBotCallManager;

/**
 *  Possible errors the account can return.
 */
typedef NS_ENUM(NSInteger, VBotAccountErrors) {
    /**
     *  Unable to configure the account
     */
    VBotAccountErrorCannotConfigureAccount,
    /**
     *  Unable to call the number
     */
    VBotAccountErrorFailedCallingNumber,
    /**
     *  Unable to register the account
     */
    VBotAccountErrorRegistrationFailed,
    /**
     *  Unable to register the account because account is invalid.
     */
    VBotAccountErrorInvalidAccount,
    /**
     *  When the account has invalid info and registrations fails with a 403.
     */
    VBotAccountErrorRegistrationFailedInvalidAccount
};
#define VBotAccountErrorsString(VBotAccountErrors) [@[@"VBotAccountErrorCannotConfigureAccount", @"VBotAccountErrorFailedCallingNumber", @"VBotAccountErrorRegistrationFailed", @"VBotAccountErrorInvalidAccount", @"VBotAccountErrorRegistrationFailedInvalidAccount"] objectAtIndex:VBotAccountErrors]

/**
 *  Possible states for an account.
 */
typedef NS_ENUM(NSInteger, VBotAccountState) {
    /**
     *  Account isn't added to the endpoint
     */
    VBotAccountStateOffline,
    /**
     *  Account is connecting with endpoint
     */
    VBotAccountStateConnecting,
    /**
     *  Account is connected with endpoint
     */
    VBotAccountStateConnected,
    /**
     *  Account is disconnected from endpoint
     */
    VBotAccountStateDisconnected,
};
#define VBotAccountStateString(VBotAccountState) [@[@"VBotAccountStateOffline", @"VBotAccountStateConnecting", @"VBotAccountStateConnected", @"VBotAccountStateDisconnected"] objectAtIndex:VBotAccountState]

/**
 *  Completionblock that will be called after the account was registered.
 *
 *  @param success BOOL will indicate the success of the registration.
 *  @param error   NSError instance with possible error. Can be nil.
 */
typedef void (^RegistrationCompletionBlock)(BOOL success, NSError * _Nullable error);

@interface VBotAccount : NSObject

/**
 *  The accountId which an account receives when it is added.
 */
@property (nonatomic) NSInteger accountId;

/**
 *  The current state of an account.
 */
@property (readonly, nonatomic) VBotAccountState accountState;

/**
 *  The current SIP registration status code.
 */
@property (readonly, nonatomic) NSInteger registrationStatus;

/**
 *  A Boolean value indicating whether the account is registered.
 */
@property (readonly, nonatomic) BOOL isRegistered;

/**
 *  An up to date expiration interval for the account registration session.
 */
@property (readonly, nonatomic) NSInteger registrationExpiresTime;

/**
 *  The account configuration that has been set in the configure function for the account.
 */
@property (readonly, nonatomic) VBotAccountConfiguration * _Nonnull accountConfiguration;

@property (readwrite, nonatomic) BOOL forceRegistration;

/**
 * This init is not available.
 */
-(instancetype _Nonnull)init __attribute__((unavailable("init not available")));

/**
 * Designated initializer
 *
 * @param callManager A instance of VBotCallManager.
 */
-(instancetype _Nonnull)initWithCallManager:(VBotCallManager * _Nonnull)callManager;

/**
 *  This will configure the account on the endpoint.
 *
 *  @param accountConfiguration Instance of the VBotAccountConfiguration.
 *  @param error                Pointer to NSError pointer. Will be set to a NSError instance if cannot configure account.
 *
 *  @return BOOL success of configuration.
 */
- (BOOL)configureWithAccountConfiguration:(VBotAccountConfiguration * _Nonnull)accountConfiguration error:(NSError * _Nullable * _Nullable)error;

/**
 *  Register the account with pjsua.
 *
 *  @param completion RegistrationCompletionBlock, will be called with success of registration and possible error.
 */
- (void)registerAccountWithCompletion:(_Nullable RegistrationCompletionBlock)completion;

/**
 *  Unregister the account if registered.
 *
 *  If an account isn't registered, there will be no unregister message sent to the proxy, and will return success.
 *
 *  @param error Pointer to NSError pointer. Will be set to a NSError instance if cannot register the account.
 *
 *  @return BOOL success if account is no longer registered
 */
- (BOOL)unregisterAccount:(NSError * _Nullable * _Nullable)error;

/**
 *  Will unregister the account and will re-register the account once the account
 *  state reaches "unregistered".
 */
- (void)reregisterAccount;

/**
 *  This will remove the account from the Endpoint and will also de-register the account from the server.
 */
- (void)removeAccount;

/**
 *  This will set the state of the account. Based on the pjsua account state and the VBotAccountState enum.
 */
- (void)accountStateChanged;

/**
 *  The number that the sip library will call.
 *
 *  @param number     The phonenumber which will be called.
 *  @param completion Completion block which will be executed when everything has been setup. May contain a outbound call or an error object.
 */
- (void)callNumber:(NSString * _Nonnull)number completion:(void(^_Nonnull)(VBotCall * _Nullable call, NSError * _Nullable error))completion;

/**
 *  This will add the call to the account.
 *
 *  @param call The call instance that should be added.
 */
- (void)addCall:(VBotCall * _Nonnull)call __attribute__((unavailable("Deprecated, use VBotCallManager -addCall: instead")));

/**
 *  This will check if there is a call present on this account given the callId.
 *
 *  @param callId The callId of the call.
 *
 *  @return VBotCall instance.
 */
- (VBotCall * _Nullable)lookupCall:(NSInteger)callId;

/**
 *  This will remove the call from the account.
 *
 *  @param call VBotCall instance that should be removed from the account.
 */
- (void)removeCall:(VBotCall * _Nonnull)call __attribute__((unavailable("Deprecated, use VBotCallManager -removeCall: instead")));;

/**
 *  Remove all calls connected to account.
 */
- (void)removeAllCalls;

/**
 *  Get the first call available to this account.
 *
 *  @return VBotCall instance can also return nil.
 */
- (VBotCall * _Nullable)firstCall;

/**
 *  Get the first active call available to this account.
 *
 *  @return VBotCall instance can also return nil.
 */
- (VBotCall * _Nullable)firstActiveCall;

@end
