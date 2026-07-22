#import "AppDelegate.h"

@interface AppDelegate ()
@property (strong) NSStatusItem *statusItem;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
  self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
  // NSStatusItem.button is 10.10+; use the 10.9 API instead.
  NSImage *icon = [self iconForState:@"stopped"];
  icon.template = YES;
  [self.statusItem setImage:icon];

  NSMenu *menu = [[NSMenu alloc] init];
  [menu addItemWithTitle:@"Quit Container Tools for Mavericks"
                  action:@selector(terminate:) keyEquivalent:@"q"];
  [self.statusItem setMenu:menu];
}

// A simple template icon drawn in code (no asset files): filled disc = running,
// ring = stopped/other. Later tasks add working/attention variants.
- (NSImage *)iconForState:(NSString *)state {
  NSImage *img = [NSImage imageWithSize:NSMakeSize(18, 18) flipped:NO
      drawingHandler:^BOOL(NSRect r) {
    NSBezierPath *p = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(r, 3, 3)];
    [[NSColor blackColor] set];
    if ([state isEqualToString:@"running"]) { [p fill]; }
    else { p.lineWidth = 1.5; [p stroke]; }
    return YES;
  }];
  return img;
}

@end
