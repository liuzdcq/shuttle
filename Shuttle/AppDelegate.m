//
//  AppDelegate.m
//  Shuttle
//

#import "AppDelegate.h"
#import <glob.h>

@implementation AppDelegate

- (instancetype)init
{
    return [self initWithHomeDirectory:NSHomeDirectory()];
}

- (instancetype)initWithHomeDirectory:(NSString *)homeDirectory
{
    self = [super init];
    if (self) configurationHomeDirectory = [homeDirectory copy];
    return self;
}

- (NSString *)expandedConfigurationPath:(NSString *)path
{
    if ([path hasPrefix:@"~/"]) {
        return [configurationHomeDirectory stringByAppendingPathComponent:[path substringFromIndex:2]];
    }
    path = [path stringByExpandingTildeInPath];
    return path.isAbsolutePath ? path : [configurationHomeDirectory stringByAppendingPathComponent:path];
}

- (NSMenuItem *)itemWithTitle:(NSString *)title action:(SEL)action
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(title, nil) action:action keyEquivalent:@""];
    item.target = self;
    return item;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Build the menu without depending on pre-Apple-silicon Interface Builder archives.
    menu = [[NSMenu alloc] initWithTitle:@"Shuttle"];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *settings = [self itemWithTitle:@"Settings" action:NULL];
    settings.submenu = [[NSMenu alloc] initWithTitle:settings.title];
    [settings.submenu addItem:[self itemWithTitle:@"Edit" action:@selector(configure:)]];
    [settings.submenu addItem:[self itemWithTitle:@"Export" action:@selector(showExportPanel:)]];
    [settings.submenu addItem:[self itemWithTitle:@"Import" action:@selector(showImportPanel:)]];
    [menu addItem:settings];
    [menu addItem:[self itemWithTitle:@"About" action:@selector(showAbout:)]];
    [menu addItem:[self itemWithTitle:@"Quit" action:@selector(quit:)]];
    permanentMenuItemCount = menu.numberOfItems;

    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Shuttle"];
    NSMenuItem *applicationItem = [[NSMenuItem alloc] init];
    applicationItem.submenu = [[NSMenu alloc] initWithTitle:@"Shuttle"];
    [applicationItem.submenu addItem:[self itemWithTitle:@"About" action:@selector(showAbout:)]];
    NSMenuItem *quit = [self itemWithTitle:@"Quit" action:@selector(quit:)];
    quit.keyEquivalent = @"q";
    [applicationItem.submenu addItem:quit];
    [mainMenu addItem:applicationItem];
    NSApp.mainMenu = mainMenu;
    
    // The location for the JSON path file. This is a simple file that contains the hard path to the *.json settings file.
    shuttleJSONPathPref = [configurationHomeDirectory stringByAppendingPathComponent:@".shuttle.path"];
    shuttleJSONPathAlt = [configurationHomeDirectory stringByAppendingPathComponent:@".shuttle-alt.path"];
    
    //if file shuttle.path exists in ~/.shuttle.path then read this file as it should contain the custom path to *.json
    if( [[NSFileManager defaultManager] fileExistsAtPath:shuttleJSONPathPref] ) {
        
        //Read the shuttle.path file which contains the path to the json file
        NSString *jsonConfigPath = [NSString stringWithContentsOfFile:shuttleJSONPathPref encoding:NSUTF8StringEncoding error:NULL];
        
        //Remove the white space if any.
        jsonConfigPath = [ jsonConfigPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        shuttleConfigFile = jsonConfigPath.length ? [self expandedConfigurationPath:jsonConfigPath] : @"";
    }else{
        // The path for the configuration file (by default: ~/.shuttle.json)
        shuttleConfigFile = [configurationHomeDirectory stringByAppendingPathComponent:@".shuttle.json"];
        
        // if the config file does not exist, create a default one
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:shuttleConfigFile] ) {
            NSString *cgFileInResource = [[NSBundle mainBundle] pathForResource:@"shuttle.default" ofType:@"json"];
            if (cgFileInResource) {
                [[NSFileManager defaultManager] copyItemAtPath:cgFileInResource toPath:shuttleConfigFile error:nil];
            }
        }
    }
    
    // if the custom alternate json file exists then read the file and use set the output as the alt path.
    if ( [[NSFileManager defaultManager] fileExistsAtPath:shuttleJSONPathAlt] ) {
        
        //Read shuttle-alt.path file which contains the custom path to the alternate json file
        NSString *jsonConfigAltPath = [NSString stringWithContentsOfFile:shuttleJSONPathAlt encoding:NSUTF8StringEncoding error:NULL];
        
        //Remove whitespace if any
        jsonConfigAltPath = [ jsonConfigAltPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        //set the global var that contains the alternate path
        shuttleAltConfigFile = jsonConfigAltPath.length ? [self expandedConfigurationPath:jsonConfigAltPath] : @"";
        
        //flag the bool for later parsing
        parseAltJSON = YES;
    }else{
        //the custom alt path does not exist. Assume the default for alt path; if existing flag for later parsing
        shuttleAltConfigFile = [configurationHomeDirectory stringByAppendingPathComponent:@".shuttle-alt.json"];
        
        if ( [[NSFileManager defaultManager] fileExistsAtPath:shuttleAltConfigFile] ){
            //the default path exists. Flag for later parsing
            parseAltJSON = YES;
        }else{
            //The user does not want to parse an additional json file.
            parseAltJSON = NO;
        }
    }
    
    regularIcon = [NSImage imageNamed:@"StatusIcon"];
    regularIcon.template = YES;
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    statusItem.menu = menu;
    statusItem.button.image = regularIcon;
    statusItem.button.toolTip = @"Shuttle";
    // Retain an accessible way to open settings even if an icon resource is missing.
    if (!regularIcon) statusItem.button.title = @">_";
    launchAtLoginController = [[LaunchAtLoginController alloc] init];
    menu.delegate = self;
    [self loadMenu];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if (statusItem) [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
}

- (void)menuWillOpen:(NSMenu *)openingMenu
{
    [self loadMenu];
}

- (BOOL)configurationError:(NSString *)message error:(NSError **)error
{
    if (error) *error = [NSError errorWithDomain:@"Shuttle.Configuration" code:1
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}

- (BOOL)validateHosts:(id)hosts depth:(NSUInteger)depth error:(NSError **)error
{
    if (![hosts isKindOfClass:NSArray.class] || depth > 32) {
        return [self configurationError:@"hosts and submenus must be arrays, nested at most 32 levels deep." error:error];
    }
    for (id item in hosts) {
        if (![item isKindOfClass:NSDictionary.class]) {
            return [self configurationError:@"Every hosts entry must be an object." error:error];
        }
        if (item[@"cmd"] || item[@"name"]) {
            for (NSString *key in @[@"cmd", @"name", @"theme", @"title", @"inTerminal"]) {
                id value = item[key];
                BOOL required = [key isEqual:@"cmd"] || [key isEqual:@"name"];
                if ((value && ![value isKindOfClass:NSString.class]) || (required && ![value length])) {
                    return [self configurationError:[NSString stringWithFormat:@"%@ must be a string; name and cmd cannot be empty.", key] error:error];
                }
            }
            if (item[@"inTerminal"] && ![@[@"new", @"tab", @"current", @"virtual"] containsObject:item[@"inTerminal"]]) {
                return [self configurationError:@"inTerminal must be new, tab, current, or virtual." error:error];
            }
        } else {
            for (NSString *key in item) {
                if (![self validateHosts:item[key] depth:depth + 1 error:error]) return NO;
            }
        }
    }
    return YES;
}

- (NSMutableDictionary *)readConfigurationAtPath:(NSString *)path error:(NSError **)error
{
    if (!path.length) {
        [self configurationError:@"The .shuttle.path or .shuttle-alt.path file is empty or unreadable." error:error];
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:error];
    if (!json) return nil;
    if (![json isKindOfClass:NSDictionary.class]) {
        [self configurationError:@"The configuration must be a JSON object." error:error];
        return nil;
    }
    for (NSString *key in @[@"terminal", @"editor", @"iTerm_version", @"open_in", @"default_theme"]) {
        if (json[key] && ![json[key] isKindOfClass:NSString.class]) {
            [self configurationError:[NSString stringWithFormat:@"%@ must be a string.", key] error:error];
            return nil;
        }
    }
    for (NSString *key in @[@"launch_at_login", @"show_ssh_config_hosts"]) {
        if (json[key] && ![json[key] isKindOfClass:NSNumber.class]) {
            [self configurationError:[NSString stringWithFormat:@"%@ must be a JSON boolean.", key] error:error];
            return nil;
        }
    }
    for (NSString *key in @[@"ssh_config_ignore_hosts", @"ssh_config_ignore_keywords"]) {
        if (json[key] && ![json[key] isKindOfClass:NSArray.class]) {
            [self configurationError:[NSString stringWithFormat:@"%@ must be an array of strings.", key] error:error];
            return nil;
        }
        for (id value in json[key]) {
            if (![value isKindOfClass:NSString.class]) {
                [self configurationError:[NSString stringWithFormat:@"%@ must contain only strings.", key] error:error];
                return nil;
            }
        }
    }
    if (!json[@"hosts"]) json[@"hosts"] = [NSMutableArray array];
    return [self validateHosts:json[@"hosts"] depth:0 error:error] ? json : nil;
}

- (void)showConfigurationError:(NSError *)error
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Error parsing config", nil)
                                               action:NULL keyEquivalent:@""];
    item.enabled = NO;
    item.toolTip = error.localizedDescription;
    [menu insertItem:item atIndex:0];
    NSLog(@"Cannot load Shuttle configuration: %@", error.localizedDescription);
}

- (void)showError:(NSString *)title details:(NSString *)details
{
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(title, nil);
    alert.informativeText = details ?: @"Unknown error";
    alert.alertStyle = NSAlertStyleWarning;
    [alert runModal];
}

- (void)showScriptError:(NSDictionary *)error
{
    NSString *details = error[NSAppleScriptErrorMessage] ?: @"The terminal script could not be loaded or executed.";
    if ([error[NSAppleScriptErrorNumber] integerValue] == -1743) {
        details = [details stringByAppendingString:@"\n\nAllow Shuttle to control Terminal or iTerm in System Settings > Privacy & Security > Automation."];
    }
    details = [details stringByAppendingString:@"\n\nTerminal's new-tab mode also requires Shuttle in Privacy & Security > Accessibility. You can use open_in: new without that permission."];
    [self showError:@"Unable to run terminal command" details:details];
}

- (NSURL *)commandURL:(NSString *)command
{
    NSURL *url = [NSURL URLWithString:command];
    // Modern Foundation accepts relative strings (and even spaces) as URLs.
    // Only an explicit scheme makes a command a URL rather than shell text.
    return url.scheme.length ? url : nil;
}

// Parsing of the SSH Config File
// Courtesy of https://gist.github.com/geeksunny/3376694
- (NSDictionary<NSString *, NSDictionary *> *)parseSSHConfigFile {
    
    NSMutableDictionary *servers = [NSMutableDictionary dictionary];
    [servers addEntriesFromDictionary:[self parseSSHConfig:@"/etc/ssh/ssh_config"]];
    [servers addEntriesFromDictionary:[self parseSSHConfig:[configurationHomeDirectory stringByAppendingPathComponent:@".ssh/config"]]];
    return servers;
}

- (NSDictionary<NSString *, NSDictionary *> *)parseSSHConfig:(NSString *)filepath {
    return [self parseSSHConfig:filepath visiting:[NSMutableSet set]];
}

- (NSDictionary *)parseSSHConfig:(NSString *)filepath visiting:(NSMutableSet *)visiting
{
    filepath = [[filepath stringByStandardizingPath] stringByResolvingSymlinksInPath];
    if ([visiting containsObject:filepath] || visiting.count >= 32) return @{};
    [visiting addObject:filepath];
    // Missing files and unmatched Include patterns are allowed by OpenSSH.
    NSString *fh = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
    
    // build the regex for matching
    NSError* error = NULL;
    NSRegularExpression* rx = [NSRegularExpression regularExpressionWithPattern:@"^(#?)[ \\t]*([^ \\t=]+)[ \\t=]+(.*)$"
                                                                        options:0
                                                                          error:&error];
    
    // create data store
    NSMutableDictionary* servers = [[NSMutableDictionary alloc] init];
    NSString* key = nil;
    
    // Loop through each line and parse the file.
    for (NSString *line in [fh componentsSeparatedByString:@"\n"]) {
        
        // Strip line
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[ NSCharacterSet whitespaceCharacterSet]];
        
        // run the regex against the line
        NSTextCheckingResult* matches = [rx firstMatchInString:trimmed
                                                       options:0
                                                         range:NSMakeRange(0, [trimmed length])];
        if ([matches numberOfRanges] != 4) {
            continue;
        }
        
        BOOL isComment = [[trimmed substringWithRange:[matches rangeAtIndex:1]] isEqualToString:@"#"];
        NSString* first = [trimmed substringWithRange:[matches rangeAtIndex:2]];
        NSString* second = [trimmed substringWithRange:[matches rangeAtIndex:3]];
        
        // check for special comment key/value pairs
        if (isComment && key && [first hasPrefix:@"shuttle."]) {
            servers[key][[first substringFromIndex:8]] = second;
        }
        
        // other comments must be skipped
        if (isComment) {
            continue;
        }
        
        if ([first caseInsensitiveCompare:@"Include"] == NSOrderedSame) {
            // Support for ssh_config Include directive.
            // Resolve Include globs and prevent self-includes from recursing forever.
            for (NSString *pattern in [second componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]) {
                if (!pattern.length) continue;
                NSString *expanded = [pattern stringByExpandingTildeInPath];
                NSString *includePath = expanded.isAbsolutePath ? expanded :
                    [[filepath stringByDeletingLastPathComponent] stringByAppendingPathComponent:expanded];
                glob_t paths = {0};
                if (glob(includePath.fileSystemRepresentation, 0, NULL, &paths) == 0) {
                    for (size_t i = 0; i < paths.gl_pathc; i++) {
                        NSString *included = [NSString stringWithUTF8String:paths.gl_pathv[i]];
                        [servers addEntriesFromDictionary:[self parseSSHConfig:included visiting:visiting]];
                    }
                }
                globfree(&paths);
            }
        }

        if ([first caseInsensitiveCompare:@"Host"] == NSOrderedSame) {
            // a new host section
            
            // split multiple aliases on space and only save the first
            NSArray* hostAliases = [second componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            hostAliases = [hostAliases filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]];
            key = [hostAliases firstObject];
            if (key.length) servers[key] = [[NSMutableDictionary alloc] init];
        }
    }
    
    [visiting removeObject:filepath];
    return servers;
}


- (void) loadMenu {
    while (menu.numberOfItems > permanentMenuItemCount) [menu removeItemAtIndex:0];
    NSError *error = nil;
    NSMutableDictionary *json = [self readConfigurationAtPath:shuttleConfigFile error:&error];
    if (!json) {
        [self showConfigurationError:error];
        return;
    }
    terminalPref = [json[@"terminal"] lowercaseString] ?: @"terminal.app";
    editorPref = json[@"editor"] ?: @"default";
    iTermVersionPref = [json[@"iTerm_version"] lowercaseString] ?: @"stable";
    openInPref = [json[@"open_in"] lowercaseString] ?: @"tab";
    themePref = json[@"default_theme"];
    shuttleHosts = json[@"hosts"];
    ignoreHosts = json[@"ssh_config_ignore_hosts"];
    ignoreKeywords = json[@"ssh_config_ignore_keywords"];

    // Re-evaluate the optional file so adding or deleting it takes effect immediately.
    parseAltJSON = [[NSFileManager defaultManager] fileExistsAtPath:shuttleAltConfigFile] ||
        [[NSFileManager defaultManager] fileExistsAtPath:shuttleJSONPathAlt];
    if (parseAltJSON) {
        NSMutableDictionary *alternate = [self readConfigurationAtPath:shuttleAltConfigFile error:&error];
        if (!alternate) {
            [self showConfigurationError:error];
            return;
        }
        [shuttleHosts addObjectsFromArray:alternate[@"hosts"]];
    }

    // Apply configuration changes once. Do not undo changes made in System Settings on each click.
    NSNumber *desired = json[@"launch_at_login"];
    if (desired && ![desired isEqual:appliedLaunchAtLogin]) {
        appliedLaunchAtLogin = desired;
        if (![launchAtLoginController setEnabled:desired.boolValue error:&error]) {
            NSString *message = error.localizedDescription;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showError:@"Unable to change login item" details:message];
            });
        }
    }

    // Should we merge ssh config hosts?
    BOOL showSshConfigHosts = YES;
    if ([[json allKeys] containsObject:(@"show_ssh_config_hosts")] && [json[@"show_ssh_config_hosts"] boolValue] == NO) {
        showSshConfigHosts = NO;
    }
    
    if (showSshConfigHosts) {
        // Read configuration from ssh config
        NSDictionary* servers = [self parseSSHConfigFile];
        for (NSString* key in servers) {
            BOOL skipCurrent = NO;
            NSDictionary* cfg = [servers objectForKey:key];
            
            // get special name from config if set, fallback to the key
            NSString* name = cfg[@"name"] ? cfg[@"name"] : key;
            
            // Ignore entries that contain wildcard characters
            if ([key rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"*?!["]].location != NSNotFound)
                skipCurrent = YES;
            
            // Ignore entries that start with `.`
            if ([name hasPrefix:@"."])
                skipCurrent = YES;
            
            // Ignore entries whose name matches exactly any of the values in ignoreHosts
            for (NSString* ignore in ignoreHosts) {
                if ([name isEqualToString:ignore]) {
                    skipCurrent = YES;
                }
            }
            
            // Ignore entries whose name contains any of the values in ignoreKeywords
            for (NSString* ignore in ignoreKeywords) {
                if ([name rangeOfString:ignore].location != NSNotFound) {
                    skipCurrent = YES;
                }
            }
            
            if (skipCurrent) {
                continue;
            }
            
            // Split the host into parts separated by / - the last part is the name for the leaf in the tree
            NSMutableArray* path = [NSMutableArray arrayWithArray:[name componentsSeparatedByString:@"/"]];
            NSString* leaf = [path lastObject];
            if (leaf == nil)
                continue;
            [path removeLastObject];
            
            NSMutableArray* itemList = shuttleHosts;
            for (NSString *part in path) {
                BOOL createList = YES;
                for (NSDictionary* item in itemList) {
                    // if we encounter an item with cmd/name then we have to bail
                    // since there's no way we can dig deeper here
                    if (item[@"cmd"] || item[@"name"]) {
                        continue;
                    }
                    
                    // if this item has the name of our target check if we can
                    // reuse it (if it's an array) - or if we need to bail
                    if (item[part]) {
                        // make sure this is an array and not an object
                        if ([item[part] isKindOfClass:[NSArray class]]) {
                            itemList = item[part];
                            createList = NO;
                        } else {
                            itemList = nil;
                        }
                        break;
                    }
                }
                
                if (itemList == nil) {
                    // things gone south... there's already something present and it's
                    // not an array...
                    break;
                }
                
                if (createList) {
                    // create a new entry and set it as itemList
                    NSMutableArray *newList = [[NSMutableArray alloc] init];
                    [itemList addObject:[NSDictionary dictionaryWithObject:newList
                                                                    forKey:part]];
                    itemList = newList;
                }
            }
            
            // if everything worked out we will see a non-nil itemList where the
            // system should be appended to. part hold the last part of the splitted string (aka hostname).
            if (itemList) {
                // build the corresponding ssh command
                NSString* cmd = [NSString stringWithFormat:@"ssh %@", key];
                
                // inject the data into the json parser result
                [itemList addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:leaf, cmd, nil]
                                                                forKeys:[NSArray arrayWithObjects:@"name", @"cmd", nil]]];
            }
        }
    }
    
    // feed the final result into the recursive method which builds the menu
    [self buildMenu:shuttleHosts addToMenu:menu];
}

- (void) buildMenu:(NSArray*)data addToMenu:(NSMenu *)m {
    // go through the array and sort out the menus and the leafs into
    // separate bucks so we can sort them independently.
    NSMutableDictionary* menus = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* leafs = [[NSMutableDictionary alloc] init];
    
    for (NSDictionary* item in data) {
        if (item[@"cmd"] && item[@"name"]) {
            // this is a leaf
            [leafs setObject:item forKey:item[@"name"]];
        } else {
            // must be a menu - add all instances
            for (NSString* key in item) {
                [menus setObject:item[key] forKey:key];
            }
        }
    }
    
    NSArray* menuKeys = [[menus allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray* leafKeys = [[leafs allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    NSInteger pos = 0;
    
    // create menus first
    for (NSString* key in menuKeys) {
        NSMenu* subMenu = [[NSMenu alloc] init];
        NSMenuItem* menuItem = [[NSMenuItem alloc] init];
        [self separatorSortRemoval:key];
        [menuItem setTitle:menuName];
        [menuItem setSubmenu:subMenu];
        [m insertItem:menuItem atIndex:pos++];
        if (addSeparator) {
            [m insertItem:[NSMenuItem separatorItem] atIndex:pos++];
        }
        // build submenu
        [self buildMenu:menus[key] addToMenu:subMenu];
    }
    
    // now create leafs
    for (NSString *key in leafKeys) {
        NSDictionary* cfg = leafs[key];
        NSMenuItem* menuItem = [[NSMenuItem alloc] init];
        
        [self separatorSortRemoval:cfg[@"name"]];
        
        // Keep structured data so commands and titles can contain any characters.
        NSMutableDictionary *command = [cfg mutableCopy];
        command[@"name"] = menuName;
        [menuItem setTitle:menuName];
        [menuItem setRepresentedObject:command];
        [menuItem setTarget:self];
        [menuItem setAction:@selector(openHost:)];
        [m insertItem:menuItem atIndex:pos++];
        if (addSeparator) {
            [m insertItem:[NSMenuItem separatorItem] atIndex:pos++];
        }
    }
}

- (void) separatorSortRemoval:(NSString *)currentName {
    NSError *regexError = nil;
    addSeparator = NO;
    
    NSRegularExpression *regexSort = [NSRegularExpression regularExpressionWithPattern:@"([\\[][a-z]{3}[\\]])" options:0 error:&regexError];
    NSRegularExpression *regexSeparator = [NSRegularExpression regularExpressionWithPattern:@"([\\[][-]{3}[\\]])" options:0 error:&regexError];
    
    NSUInteger sortMatches = [regexSort numberOfMatchesInString:currentName options:0 range:NSMakeRange(0,[currentName length])];
    NSUInteger separatorMatches = [regexSeparator  numberOfMatchesInString:currentName options:0 range:NSMakeRange(0,[currentName length])];
    //NSUInteger *totalMatches = sortMatches + separatorMatches;
    
    
    
    if ( sortMatches == 1 || separatorMatches == 1 ) {
        if (sortMatches == 1 && separatorMatches == 1 ) {
            menuName = [regexSort stringByReplacingMatchesInString:currentName options:0 range:NSMakeRange(0, [currentName length]) withTemplate:@""];
            menuName = [regexSeparator stringByReplacingMatchesInString:menuName options:0 range:NSMakeRange(0, [menuName length]) withTemplate:@""];
            addSeparator = YES;
        } else {
            
            if( sortMatches == 1) {
                menuName = [regexSort stringByReplacingMatchesInString:currentName options:0 range:NSMakeRange(0, [currentName length]) withTemplate:@""];
                addSeparator = NO;
            }
            if ( separatorMatches == 1 ) {
                menuName = [regexSeparator stringByReplacingMatchesInString:currentName options:0 range:NSMakeRange(0, [currentName length]) withTemplate:@""];
                addSeparator = YES;
            }
        }
    } else {
        menuName = currentName;
        addSeparator = NO;
    }
}

- (void)openHost:(NSMenuItem *)sender
{
    NSDictionary *command = sender.representedObject;
    NSString *text = command[@"cmd"];
    NSString *theme = command[@"theme"] ?: themePref ?: ([terminalPref containsString:@"iterm"] ? @"Default" : @"Basic");
    NSString *title = command[@"title"] ?: command[@"name"] ?: @"Shuttle";
    NSString *mode = command[@"inTerminal"] ?: openInPref;
    if (![@[@"tab", @"new", @"current", @"virtual"] containsObject:mode]) mode = @"tab";

    if ([mode isEqual:@"virtual"]) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"virtual-with-screen" ofType:@"scpt"];
        [self runScript:path handler:@"scriptRun" parameters:@[text, title]];
        return;
    }
    NSURL *url = [self commandURL:text];
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
        return;
    }

    NSString *prefix = @"terminal";
    if ([terminalPref containsString:@"iterm"]) {
        if (![@[@"stable", @"nightly"] containsObject:iTermVersionPref]) {
            [self showError:@"Invalid iTerm version" details:@"Set iTerm_version to stable or nightly in the JSON configuration."];
            return;
        }
        prefix = [@"iTerm2-" stringByAppendingString:iTermVersionPref];
    }
    NSString *suffix = @{@"new": @"new-window", @"tab": @"new-tab-default", @"current": @"current-window"}[mode];
    NSString *resource = [NSString stringWithFormat:@"%@-%@", prefix, suffix];
    NSString *path = [[NSBundle mainBundle] pathForResource:resource ofType:@"scpt"];
    // The current-window handlers accept only the command; window/tab handlers
    // also accept a profile and title.
    NSArray *parameters = [mode isEqual:@"current"] ? @[text] : @[text, theme, title];
    [self runScript:path handler:@"scriptRun" parameters:parameters];
}

- (void) runScript:(NSString *)scriptPath handler:(NSString*)handlerName parameters:(NSArray*)parametersInArray {
    //special thanks to stackoverflow.com/users/316866/leandro for pointing me the right direction.
    //see http://goo.gl/olcpaX
    NSAppleScript           * appleScript;
    NSAppleEventDescriptor  * thisApplication, *containerEvent;
    if (!scriptPath.length) {
        [self showError:@"Missing terminal script" details:@"Rebuild Shuttle from the current source tree."];
        return;
    }
    NSURL *pathURL = [NSURL fileURLWithPath:scriptPath];
    
    NSDictionary * appleScriptCreationError = nil;
    appleScript = [[NSAppleScript alloc] initWithContentsOfURL:pathURL error:&appleScriptCreationError];
    
    if (!appleScript) {
        [self showScriptError:appleScriptCreationError];
        return;
    }
    if (handlerName && [handlerName length])
    {
        /* If we have a handlerName (and potentially parameters), we build
         * an NSAppleEvent to execute the script. */
        
        //Get a descriptor
        int pid = [[NSProcessInfo processInfo] processIdentifier];
        thisApplication = [NSAppleEventDescriptor descriptorWithDescriptorType:typeKernelProcessID
                                                                         bytes:&pid
                                                                        length:sizeof(pid)];
        
        //Create the container event
        
        //We need these constants from the Carbon OpenScripting framework, but we don't actually need Carbon.framework...
#define kASAppleScriptSuite 'ascr'
#define kASSubroutineEvent  'psbr'
#define keyASSubroutineName 'snam'
        containerEvent = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite
                                                                  eventID:kASSubroutineEvent
                                                         targetDescriptor:thisApplication
                                                                 returnID:kAutoGenerateReturnID
                                                            transactionID:kAnyTransactionID];
        //Set the target handler
        [containerEvent setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:handlerName]
                                forKeyword:keyASSubroutineName];
        
        //Pass parameters - parameters is expecting an NSArray with only NSString objects
        if ([parametersInArray count])
        {
            
            NSAppleEventDescriptor  *arguments = [[NSAppleEventDescriptor alloc] initListDescriptor];
            NSString                *object;
            
            for (object in parametersInArray) {
                [arguments insertDescriptor:[NSAppleEventDescriptor descriptorWithString:object]
                                    atIndex:([arguments numberOfItems] +1)];
            }
            
            [containerEvent setParamDescriptor:arguments forKeyword:keyDirectObject];
        }
        //Execute the event
        NSDictionary *executionError = nil;
        if (![appleScript executeAppleEvent:containerEvent error:&executionError]) {
            [self showScriptError:executionError];
        }
    }
}

- (IBAction)showImportPanel:(id)sender {
    NSOpenPanel * openPanelObj	= [NSOpenPanel openPanel];
    NSInteger tvarNSInteger	= [openPanelObj runModal];
    if(tvarNSInteger == NSModalResponseOK){
        //Backup the current configuration
        [[NSFileManager defaultManager] moveItemAtPath:shuttleConfigFile toPath: [configurationHomeDirectory stringByAppendingPathComponent:@".shuttle.json.backup"] error: nil];
        
        NSURL * selectedFileUrl = [openPanelObj URL];
        //Import the selected file
        //NSLog(@"copy filename from %@ to %@",selectedFileUrl.path,shuttleConfigFile);
        [[NSFileManager defaultManager] copyItemAtPath:selectedFileUrl.path toPath:shuttleConfigFile error:nil];
        //Delete the old configuration file
        [[NSFileManager defaultManager] removeItemAtPath:[configurationHomeDirectory stringByAppendingPathComponent:@".shuttle.json.backup"]  error: nil];
    } else {
        return;
    }
    
}

- (IBAction)showExportPanel:(id)sender {
    NSSavePanel * savePanelObj	= [NSSavePanel savePanel];
    //Display the Save Panel
    NSInteger result	= [savePanelObj runModal];
    if (result == NSModalResponseOK) {
        NSURL *saveURL = [savePanelObj URL];
        // then copy a previous file to the new location
        [[NSFileManager defaultManager] copyItemAtPath:shuttleConfigFile toPath:saveURL.path error:nil];
    }
}

- (IBAction)configure:(id)sender {
    
    if (!editorPref.length || [editorPref caseInsensitiveCompare:@"default"] == NSOrderedSame) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:shuttleConfigFile]];
    } else {
        // Quote the configuration path without changing the user's editor command.
        NSString *quotedPath = [shuttleConfigFile stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
        NSString *editorCommand = [NSString stringWithFormat:@"%@ '%@'", editorPref, quotedPath];
        NSMenuItem *editorMenu = [[NSMenuItem alloc] init];
        editorMenu.representedObject = @{@"cmd": editorCommand, @"title": @"Editing Shuttle JSON", @"inTerminal": @"new"};
        [self openHost:editorMenu];
    }
}

- (IBAction)showAbout:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:sender];
}

- (IBAction)quit:(id)sender {
    [NSApp terminate:NSApp];
}

@end
