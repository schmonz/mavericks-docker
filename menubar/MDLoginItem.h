#import <Foundation/Foundation.h>

// The app's own "Open at Login" via LSSharedFileList (the idiomatic 10.9 mechanism;
// user-manageable in System Preferences). +bundleURL is this .app.
@interface MDLoginItem : NSObject
+ (BOOL)isEnabled;
+ (void)setEnabled:(BOOL)enabled;
@end
