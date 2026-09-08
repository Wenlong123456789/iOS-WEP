# Contributing To VansonLoader

Thanks for helping improve VansonLoader.

## Project Scope

VansonLoader is the dylib edition derived from the VansonMod project direction. It provides selected VM workflows inside an injected in-process floating panel.

Accepted contributions should match the Loader runtime scope:

- Floating panel stability and usability.
- Memory search, results, browsing, and value editing improvements.
- Import and runtime handling for supported `.vm` and `.vmsc` data.
- Runtime patch, signature, script, watch overlay, and inspector improvements where Loader already supports those paths.
- Build, localization, documentation, and packaging improvements.

Contributions should keep documentation accurate to Loader behavior:

- Describe supported Loader features precisely.
- Keep advanced editor-only workflows documented in VansonMod.
- Avoid claiming VansonLoader has VansonMod-only features such as full app selection, full archive management, and advanced standalone pointer search workflows.

Contributions should avoid target-specific behavior:

- No presets, workflows, bypasses, or dedicated logic for a specific app, game, service, or commercial target.
- No bundled target data, account data, private keys, certificates, profiles, or proprietary assets.
- No generated build products such as `.theos/`, `packages/`, `release/`, `Payload/`, `.deb`, `.dylib`, or `.ipa`.

## Build Checks

Before opening a pull request, run:

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

For release packaging:

```sh
./scripts/release.sh
```

## Code Guidelines

- Keep changes focused and easy to review.
- Follow the existing Objective-C++, C++, and Theos project style.
- Keep VansonLoader as an independent repository and release flow.
- Add or update localized strings when UI text changes.
- Update README or docs when behavior, build steps, release output, or supported scope changes.

## License

By contributing, you agree that your contribution is provided under GPL-3.0, the same license as this project.

