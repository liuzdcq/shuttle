# Shuttle

[![Join the chat at https://gitter.im/fitztrev/shuttle](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/fitztrev/shuttle?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

A simple shortcut menu for macOS

[http://fitztrev.github.io/shuttle/](http://fitztrev.github.io/shuttle/)

![How Shuttle works](https://raw.githubusercontent.com/fitztrev/shuttle/gh-pages/images/how-shuttle-works.gif)

**Sidenote**: *Many people ask, so here's how I have [my terminal setup](https://github.com/fitztrev/shuttle/wiki/My-Terminal-Prompt).*

## Installation

This branch modernizes Shuttle for Apple silicon, with native `arm64` and
universal (`arm64` + `x86_64`) builds. It requires **macOS 13 or later** and the
full Xcode application to build. Use the newest Xcode compatible with your Mac.
The historical upstream downloads linked above may contain Intel-only builds.

On an Apple silicon Mac, build the native app:

```bash
bash scripts/build-macos.sh arm64
```

Quit any older Shuttle instance, then copy
`build/arm64/Build/Products/Release/Shuttle.app` to `/Applications` and open it.
Your existing `~/.shuttle.json`, alternate JSON file, and SSH menu configuration
continue to work. Custom paths in `~/.shuttle.path` and `~/.shuttle-alt.path`
support `~/` and spaces; restart Shuttle after changing a path file.

For both Apple silicon and Intel Macs:

```bash
bash scripts/build-macos.sh universal
```

Both commands verify the requested executable architectures using `lipo`, sign
the app, verify its signature, and create a ZIP in `build/arm64` or
`build/universal`. The default signature is ad-hoc for local use; downloaded CI
artifacts are also ad-hoc signed and are **not notarized distribution releases**.
To distribute publicly, set `SHUTTLE_SIGN_IDENTITY` to your Developer ID
Application identity and submit the resulting app to Apple's notarization
service before distribution.

You can also open `Shuttle.xcodeproj` and run the shared **Shuttle** scheme.
Release uses Xcode's standard architectures; Debug uses the host architecture.

To check an installed copy:

```bash
lipo -archs /Applications/Shuttle.app/Contents/MacOS/Shuttle
```

On Apple silicon the output must include `arm64`. Activity Monitor's **Kind**
column should show **Apple** while Shuttle is running. A native build does not
need Rosetta. See Apple's [universal binary documentation](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
and [Rosetta support information](https://support.apple.com/en-ie/102527).

On first use, allow Shuttle to control Terminal or iTerm under **System Settings
→ Privacy & Security → Automation**. Terminal's `open_in: "tab"` mode also uses
System Events and requires **Accessibility** permission. `open_in: "new"` avoids
that extra permission. `launch_at_login` uses `SMAppService`; copy Shuttle to
`/Applications` before enabling it, and approve it in **General → Login Items**
if macOS requests approval. Remove an old Shuttle entry there if it points to
an obsolete copy of the application.

## Validation

```bash
bash scripts/test-macos.sh
```

Native tests cover programmatic menu startup, existing and invalid JSON files,
configuration recovery, alternate file reloads, SSH includes, command/URL
detection, and script argument handling. Tests use temporary files and intercept
terminal execution, so no configured command runs and no login item is changed.

GitHub Actions builds and checks both architecture variants on `macos-latest`,
runs the native tests, and uploads ZIP artifacts. The workflow reports the actual
runner OS and Xcode versions. A successful build on an older runner is not a
runtime certification for macOS 27.2; menu display, Terminal/iTerm automation,
permissions, and login startup still need to be checked on that macOS version.

Terminal profiles configured with `default_theme` or a command's `theme` are
optional appearance settings. When omitted, Shuttle keeps Terminal's current
profile. If a named profile is missing or Terminal cannot apply it, the command
continues with the current appearance; it is not rerun. Automation failures still
produce an error, and permission guidance is shown only for the corresponding
permission failure. Terminal scripts are compiled from their source during each
affected Xcode build, rather than copied from historical bytecode.

## Help
See the [Wiki](https://github.com/fitztrev/shuttle/wiki) pages. 

## Roadmap

* Cloud hosting integration
  * AWS, Rackspace, Digital Ocean, etc
  * Using their APIs, automatically add all of your machines to the menu
* Preferences panel for easier configuration
* Update notifications
* Keyboard hotkeys
  * Open menu
  * Select host option within menu

## Contributors

This project was created by [Trevor Fitzgerald](https://github.com/fitztrev). I owe many thanks to the following people who have helped make Shuttle even better.

(In alphabetical order)

* [Alexis NIVON](https://github.com/anivon)
* [Alex Carter](https://github.com/blazeworx)
* [bihicheng](https://github.com/bihicheng)
* [Dave Eddy](https://github.com/bahamas10)
* [Dmitry Filimonov](https://github.com/petethepig)
* [Frank Enderle](https://github.com/fenderle)
* [Jack Weeden](https://github.com/jackbot)
* [Justin Swanson](https://github.com/geeksunny)
* [Kees Fransen](https://github.com/keesfransen)
* Marco Aurélio
* [Martin Grund](https://github.com/grundprinzip)
* [Matt Turner](https://github.com/thshdw)
* [Michael Davis](https://github.com/mpdavis)
* [Morton Fox](https://github.com/mortonfox)
* [Pluwen](https://github.com/pluwen)
* Rebecca Dominguez
* [Rui Rodrigues](https://github.com/rmrodrigues)
* [Ryan Cohen](https://github.com/imryan)
* [Stefan Jansen](https://github.com/steffex)
* Thomas Rosenstein
* [Thoro](https://github.com/Thoro)
* [Tibor Bödecs](https://github.com/tib)
* [welsonla](https://github.com/welsonla)

## Credits

Shuttle was inspired by [SSHMenu](http://sshmenu.sourceforge.net/), the GNOME applet for Linux.

I also looked to projects such as [MLBMenu](https://github.com/markolson/MLB-Menu) and [QuickSmileText](https://github.com/scturtle/QuickSmileText) for direction on building a Cocoa app for the status bar.
