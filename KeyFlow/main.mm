// main.mm — KeyFlow native host
// Opens a WKWebView window, loads index.html, and bridges
// JavaScript calls to the C++ typing engine.
// You should NOT need to edit this file.

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <Carbon/Carbon.h>
#import "EngineWrapper.h"

// ─────────────────────────────────────────────────────────────
// JS → Native message handler
// ─────────────────────────────────────────────────────────────

@interface JSBridge : NSObject <WKScriptMessageHandler>
@property (nonatomic, strong) KFEngine *engine;
@property (nonatomic, weak)   WKWebView *webView;
@end

@implementation JSBridge

- (void)userContentController:(WKUserContentController*)ucc
      didReceiveScriptMessage:(WKScriptMessage*)msg {

    if (![msg.body isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *body = msg.body;
    NSString     *cmd  = body[@"cmd"];

    // ── start ────────────────────────────────────────────────
    if ([cmd isEqualToString:@"start"]) {

        // Check accessibility — prompt if not granted
        NSDictionary *opts = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
        if (!AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts)) {
            [self sendToJS:@"onAccessibilityNeeded" data:@{}];
            return;
        }

        NSString *text = body[@"text"];
        int delaySecs  = [body[@"delay"]        intValue];

        KFTypingConfig cfg;
        cfg.wpm         = [body[@"wpm"]         doubleValue];
        cfg.variation   = [body[@"variation"]   doubleValue];
        cfg.pauseChance = [body[@"pauseChance"]  doubleValue];
        cfg.longPauses  = [body[@"longPauses"]  boolValue];
        cfg.punctPauses = [body[@"punctPauses"] boolValue];

        __unsafe_unretained __typeof__(self) weakSelf = self;

        self.engine.onProgress = ^(int done, int total) {
            [weakSelf sendToJS:@"onProgress" data:@{
                @"done":  @(done),
                @"total": @(total)
            }];
        };
        self.engine.onDone = ^{
            [weakSelf sendToJS:@"onDone" data:@{}];
        };

        [self.engine startWithText:text delaySecs:delaySecs config:cfg];
        [self sendToJS:@"onStarted" data:@{}];
    }

    // ── pause / resume ───────────────────────────────────────
    else if ([cmd isEqualToString:@"pause"]) {
        [self.engine pause];
        [self sendToJS:@"onPaused" data:@{}];
    }
    else if ([cmd isEqualToString:@"resume"]) {
        [self.engine resume];
        [self sendToJS:@"onResumed" data:@{}];
    }

    // ── stop ─────────────────────────────────────────────────
    else if ([cmd isEqualToString:@"stop"]) {
        [self.engine stop];
        [self sendToJS:@"onStopped" data:@{}];
    }
}

// Send a callback event back to JavaScript
- (void)sendToJS:(NSString*)event data:(NSDictionary*)data {
    NSError *err;
    NSData  *json = [NSJSONSerialization dataWithJSONObject:data options:0 error:&err];
    NSString *jsonStr = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"{}";
    NSString *js = [NSString stringWithFormat:@"window.keyflow.receive('%@', %@)", event, jsonStr];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webView evaluateJavaScript:js completionHandler:nil];
    });
}

@end

// ─────────────────────────────────────────────────────────────
// App Delegate
// ─────────────────────────────────────────────────────────────

@interface AppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate>
@property (nonatomic, strong) NSWindow    *window;
@property (nonatomic, strong) WKWebView   *webView;
@property (nonatomic, strong) JSBridge    *bridge;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)n {
    // Menu
    NSMenu *bar = [[NSMenu alloc] init];
    NSMenuItem *item = [[NSMenuItem alloc] init];
    [bar addItem:item];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"Quit KeyFlow" action:@selector(terminate:) keyEquivalent:@"q"];
    item.submenu = appMenu;
    NSApp.mainMenu = bar;

    // Window — frameless, vibrancy behind
    NSRect frame = NSMakeRect(0, 0, 860, 620);
    NSWindowStyleMask style =
        NSWindowStyleMaskTitled |
        NSWindowStyleMaskClosable |
        NSWindowStyleMaskMiniaturizable |
        NSWindowStyleMaskResizable |
        NSWindowStyleMaskFullSizeContentView;

    _window = [[NSWindow alloc] initWithContentRect:frame
                                          styleMask:style
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    _window.titlebarAppearsTransparent = YES;
    _window.titleVisibility            = NSWindowTitleHidden;
    _window.movableByWindowBackground  = YES;
    _window.minSize                    = NSMakeSize(740, 540);
    _window.backgroundColor            = [NSColor clearColor];
    _window.opaque                     = NO;
    _window.hasShadow                  = YES;

    // Engine + bridge
    _bridge         = [[JSBridge alloc] init];
    _bridge.engine  = [[KFEngine alloc] init];

    // WKWebView config — register message handler "keyflow"
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.userContentController addScriptMessageHandler:_bridge name:@"keyflow"];

    // Allow local file access for CSS/assets
    config.preferences.javaScriptEnabled = YES;

    _webView = [[WKWebView alloc] initWithFrame:_window.contentView.bounds
                                  configuration:config];
    _webView.autoresizingMask    = NSViewWidthSizable | NSViewHeightSizable;
    _webView.navigationDelegate  = self;
    _webView.wantsLayer          = YES;
    _webView.layer.backgroundColor = NSColor.clearColor.CGColor;
    [_webView setValue:@NO forKey:@"drawsBackground"];

    _bridge.webView = _webView;
    [_window.contentView addSubview:_webView];

    // Load index.html from app bundle Resources
    NSURL *htmlURL = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html"];
    if (htmlURL) {
        [_webView loadFileURL:htmlURL
      allowingReadAccessToURL:[htmlURL URLByDeletingLastPathComponent]];
    }

    [_window center];
    [_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a { return YES; }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        app.activationPolicy = NSApplicationActivationPolicyRegular;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
