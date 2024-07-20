//
//  VBotCallStats.h
//  Copyright © 2017 Devhouse Spindle. All rights reserved.
//

@class VBotCall;

/**
 * The key to get the MOS value from the call stats dictionairy.
 */
extern NSString * _Nonnull const VBotCallStatsMOS;

/**
 * The key to get the active codec from the call stats dictionairy.
 */
extern NSString * _Nonnull const VBotCallStatsActiveCodec;

/**
 * The key to get the total MBs used from the call stats dictionairy.
 */
extern NSString * _Nonnull const VBotCallStatsTotalMBsUsed;

@interface VBotCallStats : NSObject

/**
 *  Make the init unavailable.
 *
 *  @return compiler error.
 */
-(instancetype _Nonnull) init __attribute__((unavailable("init not available. Use initWithCall instead.")));

/**
 *  The init to set an own ringtone file.
 *
 *  @param call VBotCall object.
 *
 *  @return VBotCallStats instance.
 */
- (instancetype _Nullable)initWithCall:(VBotCall * _Nonnull)call NS_DESIGNATED_INITIALIZER;

/**
 * Generate the call status 
 * 
 * @return NSDictionary with following format:
 * @{
 *  VBotCallStatsMOS: NSNumber,
 *  VBotCallStatsActiveCodec: NSString,
 *  VBotCallStatsTotalMBsUsed: NSNumber
 * };
 */
- (NSDictionary * _Nullable)generate;

@end
