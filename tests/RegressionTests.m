#import <Cocoa/Cocoa.h>
#import <sys/sysctl.h>
#import "AppDelegate.h"

@interface AppDelegate (Testing)
- (NSMutableDictionary *)readConfigurationAtPath:(NSString *)path error:(NSError **)error;
- (NSDictionary *)parseSSHConfig:(NSString *)path;
- (void)buildMenu:(NSArray *)data addToMenu:(NSMenu *)menu;
- (void)openHost:(NSMenuItem *)sender;
- (NSURL *)commandURL:(NSString *)command;
- (NSString *)expandedConfigurationPath:(NSString *)path;
- (NSString *)scriptErrorDetails:(NSDictionary *)error;
@end

// Exercise command parameter handling without sending Apple events or running
// any commands, and avoid consulting the machine's actual SSH configuration.
@interface TestDelegate : AppDelegate
@property (nonatomic, copy) NSArray *recordedParameters;
@end
@implementation TestDelegate
- (void)runScript:(NSString *)path handler:(NSString *)handler parameters:(NSArray *)parameters
{
    self.recordedParameters = parameters;
}
- (NSDictionary *)parseSSHConfigFile { return @{}; }
@end

static NSUInteger checks = 0;
static void Check(BOOL condition, NSString *message)
{
    checks++;
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static void Write(NSString *path, NSString *contents)
{
    NSError *error = nil;
    Check([contents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error],
          [NSString stringWithFormat:@"write fixture: %@", error]);
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        Check(argc == 3, @"test runner arguments");
        int translated = 0;
        size_t size = sizeof(translated);
        if (sysctlbyname("sysctl.proc_translated", &translated, &size, NULL, 0) == 0) {
            Check(translated == 0, @"tests must execute natively, without Rosetta");
        }
        [NSApplication sharedApplication];
        NSString *root = [NSString stringWithUTF8String:argv[1]];
        NSString *temporary = [NSString stringWithUTF8String:argv[2]];
        TestDelegate *delegate = [[TestDelegate alloc] initWithHomeDirectory:temporary];
        NSString *config = [temporary stringByAppendingPathComponent:@".shuttle.json"];

        NSError *error = nil;
        Check([delegate readConfigurationAtPath:[root stringByAppendingPathComponent:@"Shuttle/shuttle.default.json"] error:&error] != nil,
              @"shipped default configuration remains compatible");
        Check([delegate readConfigurationAtPath:[root stringByAppendingPathComponent:@"tests/.shuttle.json"] error:&error] != nil,
              @"existing nested configuration remains compatible");
        Check([delegate readConfigurationAtPath:[temporary stringByAppendingPathComponent:@"missing.json"] error:&error] == nil && error != nil,
              @"a missing configuration returns an error instead of throwing");
        for (NSString *invalid in @[@"{", @"[]", @"null", @"{\"hosts\":[null]}",
                                    @"{\"hosts\":[{\"name\":\"bad\",\"cmd\":4}]}",
                                    @"{\"hosts\":[{\"Folder\":{}}]}",
                                    @"{\"terminal\":null}", @"{\"ssh_config_ignore_keywords\":[{}]}"]) {
            Write(config, invalid);
            error = nil;
            Check([delegate readConfigurationAtPath:config error:&error] == nil && error != nil,
                  [NSString stringWithFormat:@"reject malformed configuration: %@", invalid]);
        }
        Check([[delegate expandedConfigurationPath:@"~/config with spaces.json"] isEqual:[temporary stringByAppendingPathComponent:@"config with spaces.json"]], @"custom paths expand tilde");
        Check([delegate commandURL:@"ssh user@example.com"] == nil, @"SSH command is not a relative URL");
        Check([delegate commandURL:@"top"] == nil, @"single word command is not a URL");
        Check([delegate commandURL:@"echo 'a b' | cat"] == nil, @"shell pipeline is not a URL");
        Check([[delegate commandURL:@"https://example.com/path"].scheme isEqual:@"https"], @"absolute URL remains supported");

        NSString *profileError = @"Terminal cannot set settings set dark to settings set dark.";
        NSString *details = [delegate scriptErrorDetails:@{NSAppleScriptErrorMessage: profileError, NSAppleScriptErrorNumber: @(-10006)}];
        Check([details isEqual:profileError], @"profile failures do not suggest unrelated Accessibility permissions");
        details = [delegate scriptErrorDetails:@{NSAppleScriptErrorMessage: @"Not authorized to send Apple events", NSAppleScriptErrorNumber: @(-1743)}];
        Check([details containsString:@"Automation"] && ![details containsString:@"Accessibility"], @"Apple event denial shows only Automation guidance");
        details = [delegate scriptErrorDetails:@{NSAppleScriptErrorMessage: @"Shuttle is not allowed assistive access", NSAppleScriptErrorNumber: @(-1719)}];
        Check([details containsString:@"Accessibility"], @"actual assistive access errors show Accessibility guidance");
        details = [delegate scriptErrorDetails:@{NSAppleScriptErrorMessage: @"Invalid index", NSAppleScriptErrorNumber: @(-1719)}];
        Check([details isEqual:@"Invalid index"], @"generic invalid-index errors are not misclassified as permission errors");

        NSString *ssh = [temporary stringByAppendingPathComponent:@"ssh_config"];
        NSString *included = [temporary stringByAppendingPathComponent:@"extra.conf"];
        Write(ssh, @"Include *.conf\nInclude missing-*\nHost primary.example.com\n");
        Write(included, @"Include ssh_config\nhost included.example.com\n# shuttle.name = Work/Included\n");
        NSDictionary *hosts = [delegate parseSSHConfig:ssh];
        Check(hosts.count == 2, @"Include globs and cyclic includes terminate and preserve hosts");
        Check([hosts[@"included.example.com"][@"name"] isEqual:@"Work/Included"], @"SSH menu annotations survive");
        Check([delegate parseSSHConfig:[temporary stringByAppendingPathComponent:@"absent"]].count == 0, @"missing SSH config is optional");

        NSString *text = @"printf '%s' 'quotes ¬_¬ Unicode 雪'";
        NSString *title = @"Title ¬_¬ '(null)'";
        NSMenu *commands = [[NSMenu alloc] initWithTitle:@"Tests"];
        [delegate buildMenu:@[@{@"name": @"[aaa]Host[---]", @"cmd": text, @"title": title,
                                @"theme": @"Default", @"inTerminal": @"new"}] addToMenu:commands];
        Check(commands.numberOfItems == 2 && [[commands itemAtIndex:1] isSeparatorItem], @"sort markers and separators remain supported");
        NSMenuItem *command = [commands itemAtIndex:0];
        Check([command.title isEqual:@"Host"], @"sort markers are removed from visible titles");
        Check(command.target == delegate, @"command menu item has an explicit action target");
        [delegate openHost:command];
        Check([delegate.recordedParameters isEqual:@[text, @"Default", title]], @"commands and titles retain delimiter characters and Unicode");
        command.representedObject = @{@"cmd": text, @"inTerminal": @"current"};
        [delegate openHost:command];
        Check([delegate.recordedParameters isEqual:@[text]], @"current-window handlers receive their single command argument");
        command.representedObject = @{@"cmd": text, @"title": title, @"inTerminal": @"virtual"};
        [delegate openHost:command];
        Check([delegate.recordedParameters isEqual:@[text, title]], @"virtual handlers receive command and title");

        // Exercise real programmatic startup, including recovery after malformed,
        // deleted, and newly added alternate files. No login item is registered.
        Write(config, @"{\"show_ssh_config_hosts\":false,\"hosts\":[{\"name\":\"Host\",\"cmd\":\"top\"}]}");
        [delegate applicationDidFinishLaunching:nil];
        NSMenu *statusMenu = [delegate valueForKey:@"menu"];
        Check(statusMenu.numberOfItems == 5, @"startup builds the command and permanent menus without a nib");
        [delegate openHost:[statusMenu itemAtIndex:0]];
        Check([delegate.recordedParameters isEqual:@[@"top", @"", @"Host"]], @"commands without a theme preserve Terminal's default profile");
        NSString *alternate = [temporary stringByAppendingPathComponent:@".shuttle-alt.json"];
        Write(alternate, @"{\"hosts\":[{\"name\":\"Alternate\",\"cmd\":\"pwd\"}]}");
        [delegate menuWillOpen:statusMenu];
        Check(statusMenu.numberOfItems == 6, @"adding an alternate config is detected");
        [delegate menuWillOpen:statusMenu];
        Check(statusMenu.numberOfItems == 6, @"reloading does not duplicate alternate commands");
        Write(alternate, @"broken");
        [delegate menuWillOpen:statusMenu];
        Check(statusMenu.numberOfItems == 5 && ![statusMenu itemAtIndex:0].enabled, @"malformed alternate config keeps settings reachable");
        [[NSFileManager defaultManager] removeItemAtPath:alternate error:NULL];
        [[NSFileManager defaultManager] removeItemAtPath:config error:NULL];
        [delegate menuWillOpen:statusMenu];
        Check(statusMenu.numberOfItems == 5 && ![statusMenu itemAtIndex:0].enabled, @"deleting primary config keeps settings reachable");
        Write(config, @"{\"show_ssh_config_hosts\":false}");
        [delegate menuWillOpen:statusMenu];
        Check(statusMenu.numberOfItems == 4, @"fixing primary config recovers without restarting");
        [delegate applicationWillTerminate:nil];
        NSLog(@"PASS: %lu checks", (unsigned long)checks);
    }
    return 0;
}
