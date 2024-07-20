//
//  VBotSIP.h
//  Copyright © 2015 Devhouse Spindle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CocoaLumberjack/CocoaLumberjack.h>
#import "VBotAccountConfiguration.h"
#import "VBotCallManager.h"
#import "VBotCall.h"
#import "VBotCodecConfiguration.h"
#import "VBotEndpointConfiguration.h"
#import "VBotIceConfiguration.h"
#import "VBotStunConfiguration.h"
#import "VBotTransportConfiguration.h"
#import "CallKitProviderDelegate.h"
#import "VBotEndpoint.h"


/**
 *  Key to be used for retreiving a Call object out of NSNotification user info dict.
 */
extern NSString * __nonnull const VBotNotificationUserInfoCallKey;

/**
 *  Key to be used for retreiving a CallId out of NSNotification user info dict.
 */
extern NSString * __nonnull const VBotNotificationUserInfoCallIdKey;
/**
 *  Key to be used for retreiving a render window id out of NSNotification user info dict.
 */
extern NSString * __nonnull const VBotNotificationUserInfoWindowIdKey;
/**
 *  Key to be used for retreiving a new size of render view out of NSNotification user info dict.
 */
extern NSString * __nonnull const VBotNotificationUserInfoWindowSizeKey;

/**
 * Key to be used for retrieving the currentCall state out of the NSSNotification user info dict.
 */
extern NSString * __nonnull const VBotNotificationUserInfoCallStateKey;

/**
 *  Key to be used for retrieving the current audio state for call out of the NSNotificaton user info dict.
 */
extern NSString * __nonnull const VBotNotificationUserInfoCallAudioStateKey;

/**
 *  Key to be used for retrieving the status code when there is an error setting up a call.
 */
extern NSString * __nonnull const VBotNotificationUserInfoErrorStatusCodeKey;

/**
 *  Key to be used for retrieving the status message when there is an error setting up a call.
 */
extern NSString * __nonnull const VBotNotificationUserInfoErrorStatusMessageKey;


/**
 *  Possible errors the VBotSIP can return.
 */
typedef NS_ENUM(NSUInteger, VBotSIPErrors) {
    /**
     *  Unable to configure the endpoint.
     */
    VBotSIPErrorEndpointConfigurationFailed,
    /**
     *  Unable to configure the account.
     */
    VBotSIPErrorAccountConfigurationFailed,
};
#define VBotSIPErrorsString(VBotSIPErrors) [@[@"VBotSIPErrorEndpointConfigurationFailed", @"VBotSIPErrorAccountConfigurationFailed"] objectAtIndex:VBotSIPErrors]

/**
 *  The protocol which needs to be implemented in order to use the library.
 */
@protocol SIPEnabledUser <NSObject>

/**
 *  The sip account that should be used when authenticate on remote PBX.
 *
 *  @return NSString with the password.
 */
@property (readonly, nonatomic) NSString * _Nonnull sipAccount;

/**
 *  The password that should be used when authenticate on remote PBX.
 *
 *  @return NSString with the password.
 */
@property (readonly, nonatomic) NSString * _Nonnull sipPassword;

/**
 *  The domain where the PBX can be found.
 *
 *  @return NSString with the domain.
 */
@property (readonly, nonatomic) NSString * _Nonnull sipDomain;
@optional

/**
 *  When set to YES, the account will be registered on configuration.
 *
 *  Defaults to NO.
 *
 *  @return BOOL is registration should happen.
 */
@property (readonly, nonatomic) BOOL sipRegisterOnAdd;

/**
 *  When set to YES, calls will be dropped after registration fails.
 *
 *  Default is NO.
 *
 *  @return BOOL if call should be dropped if registration fails.
 */
@property (readonly, nonatomic) BOOL dropCallOnRegistrationFailure;

/**
 *  The proxy address where to connect to.
 *
 *  If not set, the sipDomain will be used.
 *
 *  @return NSString with the proxy Address.
 */
@property (readonly, nonatomic) NSString * _Nullable sipProxy;

/**
 * Control the use of STUN for the SIP signaling.
 *
 * Default: PJSUA_STUN_USE_DEFAULT
 */
@property (nonatomic) VBotStunUse sipStunType;

/**
 * Control the use of STUN for the media transports.
 *
 * Default: PJSUA_STUN_RETRY_ON_FAILURE
 */
@property (nonatomic) VBotStunUse mediaStunType;

/**
 *  The ICE Configuration that should be used.
 */
@property (readonly, nonatomic) VBotIceConfiguration * _Nullable iceConfiguration;

/**
 * Specify if source TCP port should be used as the initial Contact
 * address if TCP/TLS transport is used. Note that this feature will
 * be automatically turned off when nameserver is configured because
 * it may yield different destination address due to DNS SRV resolution.
 * Also some platforms are unable to report the local address of the
 * TCP socket when it is still connecting. In these cases, this
 * feature will also be turned off.
 *
 *  Default: YES
 */
@property (readonly, nonatomic) BOOL contactUseSrcPort;

/**
 * This option is used to overwrite the "sent-by" field of the Via header
 * for outgoing messages with the same interface address as the one in
 * the REGISTER request, as long as the request uses the same transport
 * instance as the previous REGISTER request.
 *
 *  Default: YES
 */
@property (readonly, nonatomic) BOOL allowViaRewrite;

/**
 * This option is used to update the transport address and the Contact
 * header of REGISTER request. When this option is  enabled, the library
 * will keep track of the public IP address from the response of REGISTER
 * request. Once it detects that the address has changed, it will
 * unregister current Contact, update the Contact with transport address
 * learned from Via header, and register a new Contact to the registrar.
 * This will also update the public name of UDP transport if STUN is
 * configured.
 *
 *  Default: YES
 */
@property (readonly, nonatomic) BOOL allowContactRewrite;

/**
 * Control how Contact update will be done with the registration.
 *
 * Default: VBotContactRewriteMethodAlwaysUpdate
 */
@property (readonly, nonatomic) VBotContactRewriteMethod contactRewriteMethod;

@end // End of the SIPEnabledUser protocol

@interface VBotSIP : NSObject

/**
 *  If the endpoint is available to use.
 */
@property (readonly, nonatomic) BOOL endpointAvailable;

/**
 * If the endpoint is configured with TLS.
 */
@property (readonly, nonatomic) BOOL hasTLSTransport;

/**
 * If the endpoint is configured to use STUN.
 */
@property (readonly, nonatomic) BOOL hasSTUNEnabled;

/*
 *  The callManager used by the Lib.
 */
@property (readonly, nonatomic) VBotCallManager * _Nonnull callManager;

@property (readonly, nonatomic) VBotEndpoint * _Nonnull endpoint;

/**
 *  The shared instance for the sip library.
 */
+ (instancetype _Nonnull)sharedInstance;

/**
 *  This will configure the basic Endpoint to use with pjsip.
 *
 *  @param endpointConfiguration Instance of an endpoint configuration.
 *  @param error                 Pointer to NSError pointer. Will be set to a NSError instance if it can't configure the library.
 *
 *  @return success of configuration.
 */
- (BOOL)configureLibraryWithEndPointConfiguration:(VBotEndpointConfiguration * _Nonnull)endpointConfiguration error:(NSError * _Nullable * _Nullable)error;

/**
 *  This will create and add a VBotAccount to the Endpoint.
 *
 *  @param sipUser Instance that conforms to SIPEnabledUser protocol.
 *  @param error   Pointer to NSError pointer. Will be set to a NSError instance if it can't create a VBotAccount.
 *
 *  @return VBotAccount the account that was added. It can be null.
 */
- (VBotAccount * _Nullable)createAccountWithSipUser:(__autoreleasing id<SIPEnabledUser> _Nonnull)sipUser error:(NSError * _Nullable * _Nullable)error;

/**
 *  Register the account to the incoming sip proxy for incoming calls.
 *
 *  @param sipUser    Instance that conforms to the SIPEnabledUser protocol.
 *  @param completion Completion block which will be executed when registration has completed or failed. 
 *                    It will return the success of the registration and an account if registration was successfull.
 */
- (void)registerAccountWithUser:(__autoreleasing id<SIPEnabledUser> _Nonnull)sipUser forceRegistration:(BOOL)force withCompletion:(void (^_Nullable)(BOOL success, VBotAccount * _Nullable account))completion;

/*
 *  This will return the first account that is available.
 *
 *  @return VBotAccount instance or null.
 */
- (VBotAccount * _Nullable)firstAccount;

/*
 *  @return Returns all accounts registerd with the EndPoint
 */
- (NSArray * _Nullable)accounts;

/**
 *  Set the incoming call block for a incoming call.
 *
 *  @param incomingCallBlock block that will be invoked when an incoming call is setup.
 */
- (void)setIncomingCallBlock:(void(^ _Nonnull )(VBotCall * _Nonnull call))incomingCallBlock;

/**
 * Set the missed block for when a call is missed.
 *
 *  @param missedCallBlock block that will be invoked when a call is completed elsewhere or has been hungup before pickup 
 */
- (void)setMissedCallBlock:(void(^ _Nonnull )(VBotCall * _Nonnull call))missedCallBlock;

/**
 Set the log call back method to do own custom logging.

 @param logCallBackBlock block that will be invoked when a log message is shown.
 */
- (void)setLogCallBackBlock:(void(^ _Nonnull)(DDLogMessage * _Nonnull logMessage))logCallBackBlock;

/**
 *  Get a VBotCall with the callId.
 *
 *  @param callId   NSString the callId that needs to be found.
 *  @param sipUser  Instance that conforms to SIPEnabledUser protocol.
 *
 *  @return VSCall instance of VBotCall of nil when not found.
 */
- (VBotCall * _Nullable)getVBotCallWithId:(NSString * _Nonnull)callId andSipUser:(__autoreleasing id<SIPEnabledUser> _Nonnull)sipUser;

/**
 *  Remove the configured endpoint from PJSUA.
 */
- (void)removeEndpoint;

/**
 *  This will check if there is another call in progress.
 *
 *  @param call VBotCall instance that you want to compare to.
 *
 *  @return BOOL YES if there is a call in progress.
 */
- (BOOL)anotherCallInProgress:(VBotCall * _Nonnull)call;

/**
 *  This will update the codec configuration on the SIP endpoint
 *
 *  @param codecConfiguration VBotCodecConfiguration Instance of an VBotCodecConfiguration
 */
- (BOOL)updateCodecConfiguration:(VBotCodecConfiguration * _Nonnull)codecConfiguration;

@end
