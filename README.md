# Gitbrained

Git-synced markdown notes for mobile. Write notes on your phone, sync to any GitHub-compatible git host. Built with Flutter.

## Features

- Browse your repo as a file tree
- View notes as rendered markdown (headers, tables, code blocks, lists)
- Edit raw markdown with a toolbar for common patterns
- Save locally to device, push/pull on a configurable timer or manually
- Works with GitHub, GitLab, Gitea, Forgejo — anything with a GitHub-compatible API
- Dark theme, minimal UI, JetBrains Mono editor

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x)
- Android Studio (for the emulator / AVD manager)
- A GitHub personal access token with `repo` scope (or equivalent on your git host)

## Running in an emulator

**1. Launch the emulator**

```bash
flutter emulators --launch Medium_Phone_API_36.1
```

Wait for it to fully boot (you'll see the Android home screen).

**2. Run the app**

```bash
cd gitbrained
flutter run
```

Flutter will detect the running emulator and deploy to it automatically. You'll see a reload shortcut (`r`) in the terminal — use it after code changes without restarting.

**3. First launch**

The app opens to a settings screen. Fill in:

| Field | Example |
|-------|---------|
| Owner / Repo | `username/notes` |
| Branch | `main` |
| API base URL | `https://api.github.com` (default) |
| Personal Access Token | your PAT with `repo` scope |
| Subdirectory (optional) | `mobile` — where new notes are created |
| Sync interval | 10 minutes (default) |

Tap **Save** and you'll land in the file browser.

## Self-hosted git

Change the API base URL to your Gitea or Forgejo instance:

```
https://git.yourserver.com
```

Everything else works identically. The PAT is passed as a Bearer token in the Authorization header.

## Build a release APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

Transfer to your phone via USB or share link and install (enable "Install from unknown sources" in Android settings).

## How sync works

- **Save button** (in editor) — writes to local device storage and marks the file dirty
- **Sync** — pushes all dirty files to remote, then pulls any remote changes. Runs on the configured interval and can be triggered manually from the browser screen via the sync icon in the top bar.
- **Conflicts** — if a file was changed both locally and remotely since your last sync, it's flagged. A banner appears in the browser. The local version is preserved; the conflict must be resolved manually.

## Project structure

```
lib/
  main.dart               entry point
  app.dart                service locator, theme, root widget
  models/
    repo_item.dart        file/directory from API
    note.dart             local note + sync state types
  services/
    config_service.dart   settings (shared_preferences + secure storage)
    local_storage_service.dart  local file cache, SHA + dirty tracking
    git_service.dart      GitHub-compatible API calls
    sync_service.dart     push/pull logic, periodic timer
  screens/
    settings_screen.dart  configuration
    browser_screen.dart   repo file tree
    viewer_screen.dart    rendered markdown view
    editor_screen.dart    raw markdown editor
  widgets/
    breadcrumb_bar.dart   path navigation bar
    markdown_toolbar.dart H1–H3, bold, italic, lists, tables, code, links
```
