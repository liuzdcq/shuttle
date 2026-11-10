Run `bash scripts/test-macos.sh` from the repository root on macOS with Xcode.
The script compiles the production Objective-C files and executes
`RegressionTests.m` in the host architecture, rejecting Rosetta translation.

The runner uses an isolated temporary home directory, never registers a login
item, and intercepts AppleScript execution. Existing `.shuttle.json` and `.ssh`
fixtures remain useful for manual checks.

The test script also compiles the production Terminal scripts and runs
`TerminalAppearanceTests.applescript` against their appearance handler with fake
Terminal operations. It checks missing profiles, rejected settings, omitted and
valid themes, title failures, and authorization failures without opening Terminal
or running a connection command. Native tests also check that profile errors do
not display unrelated Accessibility guidance.

Before marking a macOS version supported, test the built app on that version:

1. Verify `lipo -archs` includes `arm64` and Activity Monitor reports **Apple**.
2. Launch from Applications; check the menu in light and dark appearance.
3. Check existing JSON menus, an alternate JSON file, SSH hosts, and reloads.
4. Execute a harmless command such as `printf 'Shuttle test\n'` in Terminal's
   new window, new tab, and current window modes. Check profiles and titles.
5. Repeat with the installed iTerm stable or nightly version, if used.
6. Deny Automation access and verify an actionable error appears; grant access
   and retry. Terminal tab creation also requires Accessibility permission.
7. Set `launch_at_login` to true after installing in Applications, approve the
   login item if requested, then log out and back in. Set it to false and check
   it is removed. Avoid keeping multiple Shuttle copies registered.

CI logs show the runner's actual macOS and Xcode versions. Until these checks
pass on macOS 27.2, compatibility with 27.2 remains awaiting device validation.
