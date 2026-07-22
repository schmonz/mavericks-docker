#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

// NSApplication's delegate is unretained on 10.9; hold it strongly here so ARC
// doesn't deallocate it after the autorelease pool drains.
static AppDelegate *gDelegate;

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    gDelegate = [[AppDelegate alloc] init];
    app.delegate = gDelegate;
    [app run];
  }
  return 0;
}
