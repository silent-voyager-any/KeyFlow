// Engine.h — KeyFlow typing engine (C++)
// Pure backend. Do not edit for UI changes.
#pragma once

#import <ApplicationServices/ApplicationServices.h>
#include <atomic>
#include <thread>
#include <string>
#include <random>
#include <functional>
#include <chrono>

struct TypingConfig {
    double wpm         = 60.0;
    double variation   = 0.40;
    double pauseChance = 0.08;
    bool   longPauses  = true;
    bool   punctPauses = true;
};

class TypingEngine {
public:
    std::atomic<bool> running{false};
    std::atomic<bool> paused{false};
    std::atomic<bool> cancelled{false};
    std::atomic<int>  progress{0};
    int               total{0};

    std::function<void()>        onDone;
    std::function<void(int,int)> onProgress;

    void start(const std::string& text, int delaySecs, TypingConfig cfg) {
        cancelled = false;
        paused    = false;
        running   = true;
        progress  = 0;
        total     = (int)text.size();

        std::thread([this, text, delaySecs, cfg]() {
            for (int i = delaySecs; i > 0 && !cancelled; --i)
                std::this_thread::sleep_for(std::chrono::seconds(1));
            if (cancelled) { running = false; return; }

            std::mt19937 rng(std::random_device{}());
            auto uni = [&](double a, double b) {
                return std::uniform_real_distribution<double>(a,b)(rng);
            };

            double base_ms = (60.0 / (cfg.wpm * 5.0)) * 1000.0;

            for (int i = 0; i < (int)text.size(); ++i) {
                while (paused && !cancelled)
                    std::this_thread::sleep_for(std::chrono::milliseconds(50));
                if (cancelled) break;

                char c = text[i];
                typeChar(c);
                progress = i + 1;
                if (onProgress) onProgress(progress, total);

                double jitter = uni(-1.0, 1.0) * cfg.variation;
                double delay  = std::max(15.0, base_ms * (1.0 + jitter));

                if (cfg.punctPauses) {
                    if (c=='.'||c=='!'||c=='?')      delay += uni(180,450);
                    else if (c==','||c==';'||c==':') delay += uni(60,140);
                    else if (c=='\n')                delay += uni(80,200);
                }
                if (uni(0,1) < cfg.pauseChance)             delay += uni(250,700);
                if (cfg.longPauses && uni(0,1) < 0.018)     delay += uni(700,2200);

                std::this_thread::sleep_for(
                    std::chrono::microseconds((long long)(delay * 1000)));
            }
            running = false;
            if (onDone) onDone();
        }).detach();
    }

    void stop()   { cancelled = true; paused = false; }
    void pause()  { paused = true; }
    void resume() { paused = false; }

private:
    void typeChar(char c) {
        CGKeyCode    code  = 0;
        CGEventFlags flags = 0;
        if (!charToKeyCode(c, code, flags)) return;
        CGEventSourceRef src  = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        CGEventRef       down = CGEventCreateKeyboardEvent(src, code, true);
        CGEventRef       up   = CGEventCreateKeyboardEvent(src, code, false);
        if (flags) {
            CGEventSetFlags(down, flags | CGEventGetFlags(down));
            CGEventSetFlags(up,   flags | CGEventGetFlags(up));
        }
        CGEventPost(kCGHIDEventTap, down);
        CGEventPost(kCGHIDEventTap, up);
        CFRelease(down); CFRelease(up); CFRelease(src);
    }

    bool charToKeyCode(char c, CGKeyCode& code, CGEventFlags& flags) {
        flags = 0;
        if (c >= 'a' && c <= 'z') {
            static const CGKeyCode a[] = {0,11,8,2,14,3,5,4,34,38,40,37,46,45,31,35,12,15,1,17,32,9,13,7,16,6};
            code = a[c-'a']; return true;
        }
        if (c >= 'A' && c <= 'Z') {
            flags = kCGEventFlagMaskShift;
            char lc = c-'A'+'a';
            return charToKeyCode(lc, code, flags = kCGEventFlagMaskShift);
        }
        if (c >= '0' && c <= '9') {
            static const CGKeyCode d[] = {29,18,19,20,21,23,22,26,28,25};
            code = d[c-'0']; return true;
        }
        struct { char ch; CGKeyCode kc; bool sh; } s[] = {
            {' ',49,0},{'\n',36,0},{'\t',48,0},{'.',47,0},{',',43,0},{'/',44,0},
            {';',41,0},{'\'',39,0},{'[',33,0},{']',30,0},{'\\',42,0},{'-',27,0},
            {'=',24,0},{'`',50,0},{'!',18,1},{'@',19,1},{'#',20,1},{'$',21,1},
            {'%',23,1},{'^',22,1},{'&',26,1},{'*',28,1},{'(',25,1},{')',29,1},
            {'_',27,1},{'+',24,1},{'{',33,1},{'}',30,1},{'|',42,1},{'<',43,1},
            {'>',47,1},{'?',44,1},{'"',39,1},{'~',50,1},{':',41,1},
        };
        for (auto& x : s) {
            if (x.ch == c) { code = x.kc; if (x.sh) flags = kCGEventFlagMaskShift; return true; }
        }
        return false;
    }
};
