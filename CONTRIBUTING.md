# Contributing

Ideas and bug reports are very welcome: open an issue or a Discussion.

## Building

macOS 14 or newer on Apple Silicon, with the Xcode Command Line Tools. No package dependencies.

```sh
./build.sh            # optimized build in build/
./build.sh --test     # all Mac tests
bash Modules/GsShare/mac/test.sh   # Windows-keyboard rules
```

The Windows app builds on Windows with `Modules/GsShare/windows/build.cmd` (uses the C# compiler that ships with Windows).

## Licence of contributions

- Changes outside `Modules/GsShare` and `Modules/GsClipboard` are accepted under GPL-3.0-or-later, like the Vorssaint code they build on.
- `Modules/GsShare` and `Modules/GsClipboard` are all rights reserved (see their LICENSE files). Please open an issue to discuss a change there rather than sending code.
