// EngineWrapper.mm
#import "EngineWrapper.h"
#import "Engine.h"

@implementation KFEngine {
    TypingEngine _engine;
}
- (BOOL)isRunning { return _engine.running.load(); }
- (BOOL)isPaused  { return _engine.paused.load();  }

- (void)startWithText:(NSString*)text delaySecs:(int)d config:(KFTypingConfig)cfg {
    TypingConfig cc;
    cc.wpm = cfg.wpm; cc.variation = cfg.variation; cc.pauseChance = cfg.pauseChance;
    cc.longPauses = cfg.longPauses; cc.punctPauses = cfg.punctPauses;

    __unsafe_unretained __typeof__(self) weakSelf = self;
    _engine.onProgress = [weakSelf](int done, int total) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.onProgress) weakSelf.onProgress(done, total);
        });
    };
    _engine.onDone = [weakSelf]() {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.onDone) weakSelf.onDone();
        });
    };
    _engine.start(std::string(text.UTF8String), d, cc);
}
- (void)pause  { _engine.pause();  }
- (void)resume { _engine.resume(); }
- (void)stop   { _engine.stop();   }
@end
