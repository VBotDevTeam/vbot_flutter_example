//
//  VBotLogging.h
//  Copyright © 2017 Devhouse Spindle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface VBotLogging : NSObject

#define VBotLog(flag, fnct, frmt, ...) \
[VBotLogging logWithFlag: flag file:__FILE__ function: fnct line:__LINE__ format:(frmt), ## __VA_ARGS__]

#define VBotLogVerbose(frmt, ...)    VBotLog(DDLogFlagVerbose,    __PRETTY_FUNCTION__, frmt, ## __VA_ARGS__)
#define VBotLogDebug(frmt, ...)      VBotLog(DDLogFlagDebug,      __PRETTY_FUNCTION__, frmt, ## __VA_ARGS__)
#define VBotLogInfo(frmt, ...)       VBotLog(DDLogFlagInfo,       __PRETTY_FUNCTION__, frmt, ## __VA_ARGS__)
#define VBotLogWarning(frmt, ...)    VBotLog(DDLogFlagWarning,    __PRETTY_FUNCTION__, frmt, ## __VA_ARGS__)
#define VBotLogError(frmt, ...)      VBotLog(DDLogFlagError,      __PRETTY_FUNCTION__, frmt, ## __VA_ARGS__)

+ (void) logWithFlag:(DDLogFlag)flag
                file: (const char *_Nonnull)file
            function:(const char*_Nonnull)function
                line:(NSUInteger)line
              format:(NSString * _Nonnull)format, ... NS_FORMAT_FUNCTION(5, 6);
@end
