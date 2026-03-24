// EngineWrapper.h — ObjC++ bridge between C++ engine and WKWebView
#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    double wpm;
    double variation;
    double pauseChance;
    BOOL   longPauses;
    BOOL   punctPauses;
} KFTypingConfig;

@interface KFEngine : NSObject
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) BOOL isPaused;
@property (nonatomic, copy, nullable) void (^onProgress)(int done, int total);
@property (nonatomic, copy, nullable) void (^onDone)(void);
- (void)startWithText:(NSString *)text delaySecs:(int)d config:(KFTypingConfig)cfg;
- (void)pause;
- (void)resume;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
