//
//  main.m
//  Shuttle
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        // The application delegate is weak; keep it alive through the run loop.
        __attribute__((objc_precise_lifetime)) AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
    }
    return 0;
}
