# nixpkgs PR: renode-bin aarch64-darwin support

## Summary

Extends `renode-bin` to support `aarch64-darwin` using the native arm64 macOS DMG
released by Antmicro alongside the existing Linux tarball. The package already has
native arm64 support as of 1.14 (see [Renode blog post](https://renode.io/news/native-64-bit-arm-host-support-in-renode)).

The macOS DMG uses APFS formatting, so `undmg` (HFS only) cannot be used. The
`unpackPhase` instead mounts with `/usr/bin/hdiutil`, copies the app bundle, and
detaches. `dontStrip = true` is required because Nix's default `strip -S` corrupts
.NET single-file bundles by removing the embedded assembly sections (reducing the
178 MB bundle to ~10 MB and causing "Arithmetic overflow" at startup).

## Key implementation details

- **GUI via `--ui` flag**: The non-dotnet DMG ships a Neutralinojs-based GUI
  (`renode-ui` binary) that acts as a WebSocket frontend to the Renode backend.
  It cannot be launched standalone. The `renode-gui` wrapper runs
  `renode --ui "$@"` which spawns the frontend automatically.

- **Ad-hoc codesigning**: `renode-ui` links `WebKit.framework`, which requires a
  valid code signature on modern macOS. Without signing, the kernel SIGKILL's the
  process immediately. `postFixup` runs
  `/usr/bin/codesign --force --sign - --deep` on the `.app` bundle.

- **DMG source**: Uses `renode-latest.osx-arm64-portable.dmg` from
  `builds.renode.io` (the non-dotnet variant which includes the native GUI binary).

## Commits

1. `renode-bin: add aarch64-darwin support` — hdiutil unpack, dontStrip, libgdiplus rpath patching
2. `renode-bin: switch to non-dotnet DMG for macOS GUI support` — use the DMG with native GUI
3. `renode-bin: fix renode-gui to use renode-ui binary directly` — initial wrapper attempt
4. `renode-bin: fix renode-gui to use renode --ui` — correct wrapper using backend's `--ui` flag
5. `renode-bin: ad-hoc codesign .app bundle for macOS` — fix SIGKILL from Gatekeeper

## Known limitations

- **`showAnalyzer` not supported in `--ui` mode**: The Neutralinojs UI is marked
  "Experimental" and does not support display analyzer windows. Use telnet mode
  (`-P <port>`) with an external viewer for framebuffer visualization.
- **`renode-latest` URL**: The DMG URL uses `renode-latest` which may change hash
  between builds. For a stable PR, pin to a versioned release URL when one becomes
  available.

## Things done

- Built on platform:
  - [ ] x86_64-linux
  - [ ] aarch64-linux
  - [ ] x86_64-darwin
  - [x] aarch64-darwin
- Tested, as applicable:
  - [ ] NixOS tests
  - [ ] Package tests at `passthru.tests`
  - [ ] Tests in `lib/tests` or `pkgs/test`
- [ ] Ran `nixpkgs-review` on this PR
- [x] Tested basic functionality of all binary files (`renode --version`, `renode --help`, loaded a built-in STM32H743 platform description, ran firmware ELF with LTDC display)
- [x] Tested `renode-gui` (launches Neutralinojs UI, connects to backend)
- [x] Tested telnet mode (`renode --disable-gui -P 1234`) with external framebuffer viewer
- Nixpkgs Release Notes
  - [ ] Package update: when the change is major or breaking.
- NixOS Release Notes
  - [ ] Module addition
  - [ ] Module update
- [x] Fits CONTRIBUTING.md, pkgs/README.md, maintainers/README.md and other READMEs
- [x] Follows the automation/AI policy — assisted by Kiro (claude-sonnet-4.6); all output reviewed before submission. Commits include `Assisted-by: Kiro (claude-sonnet-4.6)` trailer.

### Notes for reviewers

- The existing Linux path is unchanged; the Darwin-specific code is entirely inside
  `if stdenv.hostPlatform.isDarwin then ... else ...` guards.
- `hdiutil` is a macOS system tool available in the Nix sandbox at `/usr/bin/hdiutil`.
- `/usr/bin/codesign` is similarly available in the macOS sandbox.
- The `renode-test` wrapper is included but not tested here (requires Robot Framework
  test suites; basic `renode` CLI is validated).
- x86_64-darwin is not covered by this PR (no x86 macOS DMG released for 1.16.1;
  `renode_1.16.1.dmg` is the legacy Mono/x86 build — a separate effort).
- The `libgdiplus` rpath patching in `postFixup` is guarded by `if [ -f "$gdiplus" ]`
  and is a no-op for the current non-dotnet DMG (which doesn't ship libgdiplus).
