# AGENTS.md

Instructions for AI coding agents working in `zedu-desktop` (Flutter, targeting macOS, Windows and Linux).

**Read `CONTRIBUTING.md` first.** It is the source of truth for the workflow: tickets, branches, PR titles, testing, CI, PRs and secrets. This file adds only what an agent needs on top of it. Where the two disagree, `CONTRIBUTING.md` wins.

## Hard rules

- Work only on a ticket branch in the team's org fork (not a personal fork). Never push to `dev`, `central-staging` or `main`, and never target `zeduchat` directly. PRs go into `zedu-hng/zedu-desktop:dev`.
- Keep the change to what the ticket asks. No drive-by refactors, renames or dependency bumps.
- Don't edit protected files (`.github/`, `AGENTS.md`, `CONTRIBUTING.md`, tooling config; full list in `CONTRIBUTING.md` Protected files). The **Protected files** check fails the PR unless a reviewer approved the change first.
- One author per PR: commit only as the contributor, never mix in other people's commits.
- Never commit `.env`. It's gitignored but listed as a pubspec asset, so the build needs it to exist locally (`cp .env.example .env`). Only put safe, non-secret values in `.env.example`.
- Never hardcode secrets. Read config through `AppConfig.fromEnvironment()` (`lib/core/config/app_config.dart`): `--dart-define`, then `.env`, then the built-in default.
- Don't hand-edit generated files: `linux/flutter/generated_plugin_registrant.*`, `linux/flutter/generated_plugins.cmake`, and the same files under `windows/flutter/`. Flutter regenerates them.

## Commands

```sh
cp .env.example .env    # once; required as a build asset
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter run -d macos    # or windows / linux
```

CI pins Flutter **3.41.5**. Run format, analyze and test before declaring a change done. Analyze treats infos as failures.

## Layout

`lib/` is organised by feature, with clean-architecture layers inside each feature:

| Path | Holds |
|---|---|
| `main.dart` | Boot: window manager → `loadAppEnv()` → `setupLocator()` → `ProviderScope(App)` |
| `app/` | Root `App` widget |
| `core/` | Shared code: `api_utils` (Dio client, interceptors, `ApiResponseModel`), `config`, `locator` (get_it), `navigator` (go_router), `network`, `secure_storage`, `theme`, `utils` (`Result`, logger, extensions, validators), `widgets`, `mock`, `packages` |
| `features/<name>/` | auth, home, dms, channels, credits, organization, sidebar, user_profile, workspaces |
| `features/<name>/data/` | Remote datasources, models, repository implementations |
| `features/<name>/domain/` | Entities, repository interfaces, services |
| `features/<name>/presentation/` | Views, widgets, Riverpod providers |

New features follow the same `data/` → `domain/` → `presentation/` split.

## Conventions

- **Imports through barrels:** code imports `package:zedu/core/core.dart` and `package:zedu/features/features.dart`, not relative paths or individual files. Every folder has a barrel (`<feature>.dart`, `data.dart`, `providers.dart`, …); export new files from the matching one.
  - Third-party packages are re-exported from `lib/core/packages/packages.dart`. Add new package exports there.
  - `lib/core` must not import `features.dart`, except `core/navigator/app_router.dart`. That would create a circular import; `scripts/clean_barrel_imports.py` strips such imports.
- **State:** Riverpod 3. Use `Notifier` + `NotifierProvider` for new state, with providers wired in the feature's `*_providers_di.dart`. `StateProvider`, `ChangeNotifierProvider` and the `flutter_riverpod/legacy.dart` API are legacy; don't use them in new code.
- **Dependency injection:** app-wide services come from `locator<T>()` (get_it, `core/locator/`).
- **Errors:** repositories return the sealed `Result` (`Success` / `Failure`) from `core/utils/result.dart`. Handle both cases; don't throw across layers.
- **Networking:** go through `ApiBaseService` (`core/api_utils/api_client.dart`) from a feature's `*_remote_datasource.dart`. The auth interceptor attaches the token and reports 401s.
- **Routing:** go_router. Add routes and path constants in `lib/core/navigator/app_router.dart`.
- **Theming:** use `AppPalette` tokens, `app_typography.dart` styles and the context extensions in `core/utils/extensions.dart`. Don't hardcode colours or text styles. Only a light theme exists.
- **Naming:** snake_case files with role suffixes (`_view.dart`, `_notifier.dart`, `_provider.dart`, `_state.dart`, `_repository_impl.dart`, `_remote_datasource.dart`, `_model.dart`, `_service.dart`); PascalCase classes.
- **Mock data:** `USE_MOCK_DATA` and `lib/core/mock/` exist, and the chat websocket service is currently a mock stream. Check before assuming a feature talks to a real backend.

## Tests

`flutter_test` + `mocktail`. Tests mirror `lib/features` under `test/unit/features/...` and `test/widget/features/...`. Import `test/helpers/helpers.dart`, and wrap widgets with `buildTestMaterialApp` from `test/helpers/test_material_app.dart`. Follow the test-scope rules in `CONTRIBUTING.md`: tests for what the ticket changed, not retroactive coverage.

## Native projects

`macos/Podfile.lock` and the `Runner.xcodeproj/project.pbxproj` files are committed. Commit changes to them only when the ticket changes native dependencies or project settings. Local Flutter versions newer than CI's 3.41.5 can rewrite `macos/Podfile`, `project.pbxproj` and `pubspec.lock` on `flutter build` or `pub get`; revert those changes unless the ticket needs them.

## PRs

The PR title follows Conventional Commits (see `CONTRIBUTING.md`) and becomes the squashed commit on `dev`. Fill in every section of the PR template.
