//
//  LaunchAtLoginController.m
//
//  Copyright 2011 Tomáš Znamenáček
//  Copyright 2010 Ben Clark-Robinson
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the ‘Software’),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED ‘AS IS’, WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "LaunchAtLoginController.h"
#import <ServiceManagement/ServiceManagement.h>

@implementation LaunchAtLoginController

- (BOOL)launchAtLogin
{
    return SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
}

- (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error
{
    SMAppService *service = SMAppService.mainAppService;
    SMAppServiceStatus status = service.status;
    // Respect a pending approval instead of re-registering on every menu open.
    if (enabled && (status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval)) return YES;
    if (!enabled && (status == SMAppServiceStatusNotRegistered || status == SMAppServiceStatusNotFound)) return YES;
    return enabled ? [service registerAndReturnError:error] : [service unregisterAndReturnError:error];
}

- (void)setLaunchAtLogin:(BOOL)enabled
{
    NSError *error = nil;
    if (![self setEnabled:enabled error:&error]) {
        NSLog(@"Cannot update launch at login: %@", error.localizedDescription);
    }
}
@end
