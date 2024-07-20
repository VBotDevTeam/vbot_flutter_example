//
//  VBotTransportConfiguration.h
//  Copyright © 2015 Devhouse Spindle. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <VialerPJSIP/pjsip/sip_types.h>

/**
 *  The available transports to configure.
 */
typedef NS_ENUM(NSUInteger, VBotTransportType) {
    /**
     *  UDP
     */
    VBotTransportTypeUDP = PJSIP_TRANSPORT_UDP,
    /**
     *  UDP6
     */
    VBotTransportTypeUDP6 = PJSIP_TRANSPORT_UDP6,
    /**
     *  TCP
     */
    VBotTransportTypeTCP = PJSIP_TRANSPORT_TCP,
    /**
     *  TCP6
     */
    VBotTransportTypeTCP6 = PJSIP_TRANSPORT_TCP6,
    /**
     * TLS
     */
    VBotTransportTypeTLS = PJSIP_TRANSPORT_TLS,
    /**
     * TLS6
     */
    VBotTransportTypeTLS6 = PJSIP_TRANSPORT_TLS6

};
#define VBotTransportTypeString(VBotTransportType) [@[@"VBotTransportTypeUDP", @"VBotTransportTypeUDP6", @"VBotTransportTypeTCP", @"VBotTransportTypeTCP6", @"VBotTransportTypeTLS", @"VBotTransportTypeTLS6"] objectAtIndex:VBotTransportType]

@interface VBotTransportConfiguration : NSObject
/**
 *  The transport type that should be used.
 */
@property (nonatomic) VBotTransportType transportType;

/**
 *  The port on which the communication should be set up.
 */
@property (nonatomic) NSUInteger port;

/**
 *  The port range that should be used.
 */
@property (nonatomic) NSUInteger portRange;

/**
 *  This function will init a VBotTransportConfiguration with default settings
 *
 *  @param transportType Transport type that will be set.
 *
 *  @return VBotTransportConfiguration instance.
 */
+ (instancetype _Nullable)configurationWithTransportType:(VBotTransportType)transportType;

#define VBotTransportStateName(pjsip_transport_state) [@[@"PJSIP_TP_STATE_CONNECTED", @"PJSIP_TP_STATE_DISCONNECTED", @"PJSIP_TP_STATE_SHUTDOWN", @"PJSIP_TP_STATE_DESTROY"] objectAtIndex:pjsip_transport_state]

@end
