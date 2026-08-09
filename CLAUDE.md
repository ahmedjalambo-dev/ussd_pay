# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

USSD Pay is an offline-first Android app for Palestinian mobile-wallet payments. It builds a USSD string from a wallet template + recipient + amount, shows it to the user, and hands it to the system dialer. It never places calls, never touches the network, and never handles a PIN.

## Commands

```bash
flutter pub get
flutter analyze                        # lints via flutter_lints
flutter test                           # all tests
flutter test test/ussd_service_test.dart          # one file
flutter test --plain-name "JawwalPay to a friend" # one test by name
flutter run                            # debug on a connected device
flutter build apk --release            # release is minified + resource-shrunk
flutter gen-l10n                       # regenerate lib/l10n/generated/ after editing .arb
```

`flutter gen-l10n` runs implicitly on build/run (`generate: true` in pubspec), but run it explicitly after editing an `.arb` file so the analyzer sees the new getters.

## Architecture

**The money path.** `wallets.json` template → `PhoneNormalizer.normalize` → `UssdService.buildForWallet` → `ConfirmScreen` → `DialerService.dial`. Every step in that chain is written defensively on purpose; treat changes to it as high-risk and cover them with tests.

- [lib/services/ussd_service.dart](lib/services/ussd_service.dart) — pure Dart, no Flutter imports. Substitutes `{phone}`/`{amount}` into a template. The `_safeValue` regex (digits + at most one decimal point) is an **injection guard**: `*` and `#` are USSD control characters, so an unvalidated amount could restructure the command into a different transaction. It throws `UssdBuildException` rather than dialing anything it cannot vouch for, including if any placeholder survives substitution.
- [lib/services/phone_normalizer.dart](lib/services/phone_normalizer.dart) — pure Dart. Collapses every input form (`+970`, `00972`, bare 9-digit, Arabic-Indic digits, RTL marks, spaces) to the local `0599123456` form the templates expect. Invalid/unknown prefixes **warn, never block** — carriers add prefixes faster than apps ship.
- [lib/services/dialer_service.dart](lib/services/dialer_service.dart) — `Uri(scheme: 'tel', path: code)` encodes `#` as `%23`; a raw `#` would be parsed as a URI fragment and truncate the code. Falls back to the clipboard on non-Android or when no dialer exists.
- [lib/screens/confirm_screen.dart](lib/screens/confirm_screen.dart) — the mandatory review step. No path to the dialer skips it, and nothing dials automatically. History is written *before* the hand-off, since the app may be backgrounded and never learns the outcome.

**No PIN, anywhere.** The wallet PIN is entered in the carrier's own USSD dialog after dialing. It must never appear in a template, a `PaymentDraft`, a `HistoryEntry`, or a dialed string — that would leak it into the call log. There is no `CALL_PHONE` permission and no direct-dial path.

**Wallets are data, not code.** [assets/wallets.json](assets/wallets.json) is the single source of truth for carrier codes. Nothing in `lib/` hardcodes a wallet id or USSD code — adding a wallet or fixing a changed carrier code is a JSON edit plus a rebuild. `WalletConfig.fromJson` fails loudly on malformed config; `walletsProvider` stays an `AsyncValue` so a parse error surfaces as an error screen rather than an empty list.

**State** is Riverpod, hand-written, no codegen ([lib/providers/app_providers.dart](lib/providers/app_providers.dart)). `storageServiceProvider` throws by default and is overridden in `main` after `StorageService.open()`, so the rest of the app reads storage synchronously. `PaymentDraft` is the in-memory payment in progress; typing a phone number by hand clears any attached `recipientName` so a stale name can never sit beside a new number.

**Storage** ([lib/services/storage_service.dart](lib/services/storage_service.dart)) is `hive_ce` (the maintained fork; original `hive` is abandoned). Favorites and history are AES-encrypted with a key held in the Android Keystore via `flutter_secure_storage`; settings are deliberately unencrypted so the app still starts in the right language if the Keystore entry is lost. History is capped at 200 entries. Hive returns `Map<dynamic, dynamic>`, so all `fromMap` parsing goes through the helpers in [lib/core/json_map.dart](lib/core/json_map.dart) and returns `null` on bad rows rather than throwing.

**Localization** is Arabic-first: with nothing saved the app opens in `ar`, not the device locale. Theme defaults to dark. Add strings to both [lib/l10n/app_en.arb](lib/l10n/app_en.arb) and [lib/l10n/app_ar.arb](lib/l10n/app_ar.arb).

**RTL has three distinct cases** — mixing them up is the source of most bugs here:
1. *App-built strings* (USSD codes, amounts) are unconditionally LTR: wrap the `Text` in `Directionality(textDirection: ltr)`. `*` and `#` are bidi-neutral, so an Arabic paragraph reorders a code the user is being asked to approve.
2. *Number input fields* set `textDirection: ltr` + `hintTextDirection: ltr` on the `TextField` itself, never on a wrapper. Wrapping the field strands the Arabic label and prefix icon on the left.
3. *User-supplied text* (favorite and contact names) uses `directionOf(text)` from [lib/core/formatting.dart](lib/core/formatting.dart), which detects direction per string — a name typed as digits or Latin letters gets reordered otherwise.

Never nest `Directionality(ltr) > Align(AlignmentDirectional.centerStart)`: "start" then resolves to *left*, pinning the row to the wrong edge in Arabic. Alignment belongs outside, direction inside. [test/input_direction_test.dart](test/input_direction_test.dart) and [test/ussd_preview_test.dart](test/ussd_preview_test.dart) pin these down.

## Conventions

- Comments in this codebase explain *why*, especially where a guard exists because the failure mode is "money goes to the wrong place". Preserve them; match that style when adding to the money path.
- `UssdService` and `PhoneNormalizer` must stay Flutter-free so they remain directly unit-testable without a binding.
- [lib/theme/app_theme.dart](lib/theme/app_theme.dart) is the single source of design tokens — spacing, radii, the type scale, and every component theme. Screens read `Theme.of(context).textTheme.*`; a bare `TextStyle(fontSize: …)` in a screen means the scale is being bypassed. The 60dp touch targets and raised contrast (`contrastLevel: 0.3`) are for cheap devices in bright sunlight, not arbitrary. `AppTheme.ussdCode` deliberately stays monospace while the rest of the app is IBM Plex Sans — codes must render in fixed columns to be checkable.
- The button themes use `Size.fromHeight`, whose **width is `double.infinity`** — right for full-width CTAs, but it overflows a dialog's action row and stacks the buttons. Dialog actions pass `AppTheme.dialogActionSize`.
- IBM Plex Sans (Latin) and IBM Plex Sans Arabic are bundled in `assets/fonts/` (SIL OFL, licences included) rather than fetched at runtime, since the app makes no network calls. Static instances per weight, not the variable TTF — Flutter picks a face by `fontWeight`. The Arabic family is wired as `fontFamilyFallback` on the theme, so Arabic glyphs render in IBM Plex Sans Arabic regardless of the app locale.
- Dependency versions in [pubspec.yaml](pubspec.yaml) carry inline comments explaining each pin (notably `flutter_secure_storage` held below 11.x for Android SDK reasons). Read them before upgrading.
- `minSdk = 24` is pinned explicitly in [android/app/build.gradle.kts](android/app/build.gradle.kts) so a Flutter upgrade cannot silently raise it. Release builds currently sign with debug keys (TODO in the file).
