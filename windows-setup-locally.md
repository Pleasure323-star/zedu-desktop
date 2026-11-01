# Running Zedu Desktop on Windows(locally)

Follow this guide on a fresh Windows clone to get from `git clone` to a running app locally. It was written with Flutter 3.47.7 and Visual Studio 2026 Community with the **Desktop development with C++** workload.

Before you start:

- Run every command in **PowerShell**.
- Do not run Flutter as administrator.
- Never commit or share your `.env` file or paste its contents anywhere.
- Do the steps in order. Step 5 is expected to fail, and step 6 fixes it.

Back to the [main README](README.md).

## Setup

### Step 1. Check your tools

```powershell
flutter doctor
```

Flutter and Visual Studio with the C++ desktop tools must be green. The Android SDK warning can be ignored for a Windows build.

### Step 2. Clone into a short path

Use a short path with no spaces.

```powershell
cd C:\
mkdir dev
cd dev
git clone https://github.com/hngprojects/zedu-desktop.git
cd zedu-desktop
git checkout <your-branch>
```

### Step 3. Create the `.env` file

Copy the template, or ask your team lead for the dev values. Then confirm Git ignores the file.

```powershell
Copy-Item .env.example .env
git check-ignore -v .env
```

The last command must print a rule from `.gitignore`. If it prints nothing, do not add the file to Git.

### Step 4. Get the packages

```powershell
flutter pub get
```

### Step 5. Run once (expected to fail)

```powershell
flutter run -d windows
```

This run fails with `Cannot extract through symlink` (see [Error 1](#error-1-agora-sdk-extraction-fails)). That is expected. It still downloads the Iris zip that step 6 needs.

### Step 6. Fix the Agora SDK

Put both Agora SDKs in the plugin's `lib` folders yourself, then create an empty `.plugin_dev` file so the plugin skips its own extraction. This changes the Pub cache on your machine, not the repo.

Run these in one PowerShell window.

```powershell
$plugin = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\agora_rtc_engine-6.5.4\windows"

# Iris SDK: extract the downloaded zip, then move the folder into lib
$iris = "$plugin\third_party\iris"
$irisZip = "$iris\iris_4.5.3-build.1_DCG_Windows_Video_Standalone_20260428_1050_31959.zip"
Expand-Archive $irisZip -DestinationPath $iris -Force
New-Item -ItemType Directory "$iris\lib" -Force | Out-Null
Move-Item "$iris\iris_4.5.3-build.1_DCG_Windows" "$iris\lib\"

# Native SDK: download (large, can take a few minutes) and extract into lib
$native = "$plugin\third_party\native"
New-Item -ItemType Directory "$native\lib" -Force | Out-Null
$name = "Agora_Native_SDK_for_Windows_rel.v4.5.3.70_32091_FULL_20260416_1933_1076734.zip"
Invoke-WebRequest "https://download.agora.io/sdk/release/$name" -OutFile "$native\$name"
Expand-Archive "$native\$name" -DestinationPath "$native\lib" -Force

# Tell the plugin to skip its own extraction
New-Item -ItemType File "$plugin\.plugin_dev" -Force
```

Folder and file names are for `agora_rtc_engine` 6.5.4. For another version, copy the names from the plugin's `windows\cmake\DownloadSDK.cmake`.

### Step 7. Clean and run

```powershell
cd C:\dev\zedu-desktop
flutter clean
flutter pub get
$env:CL = "/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"
flutter run -d windows
```

- `flutter clean` removes stale build files left by the failed run in step 5.
- `$env:CL` fixes the `audioplayers_windows` compiler error. It lasts only for this PowerShell window, so run `flutter run` in the same window.

A successful build ends with `Built build\windows\x64\runner\Debug\zedu.exe` and the app window opens. The first build took about 2.5 minutes.

For later runs, you only need the last two lines of step 7 (set `$env:CL`, then `flutter run -d windows`) in a fresh PowerShell window.

## Build errors

If you hit an error, find it here. Each one is already handled by the steps above, so this section explains what it means.

### Error 1: Agora SDK extraction fails

```txt
Cannot extract through symlink ... .plugin_symlinks\agora_rtc_engine
```

**Cause:** The `agora_rtc_engine` CMake script deletes and re-extracts its SDK zips on every build, through a symlink that CMake refuses to write through. Developer Mode and a shorter path did not fix it.

**Fix:** Step 6.

### Error 2: Missing `.env` asset

```txt
No file or variants found for asset: .env
```

**Cause:** A fresh clone has no `.env` file because Git ignores it.

**Fix:** Step 3.

### Error 3: Compiler error STL1011 in `audioplayers_windows`

```txt
error STL1011: The /await compiler option, <experimental/coroutine> ... are deprecated
```

**Cause:** The newer Visual Studio compiler treats an old coroutine header as an error. The plugin has not been updated for it.

**Fix:** Set `$env:CL` as in step 7, then build in the same PowerShell window. It changes no files.

### Error 4: Install step fails with a Program Files path

```txt
file cannot create directory: C:/Program Files/zedu. Maybe need administrative privileges.
```

**Cause:** The install step tried to copy the app into `C:/Program Files`, which Windows blocks. Stale CMake files left in the build folder by earlier failed runs were the likely cause.

**Fix:** Run the commands in step 7, starting with `flutter clean`. This does not touch the Pub cache, so the Agora fix stays. Do not run Flutter as administrator to get around it.

## Finding a hidden build error

When a build fails with a long, unclear log, save the whole log and search it. Set `$env:CL` from step 7 first.

```powershell
$log = "$env:TEMP\zedu-build.log"
flutter build windows --debug -v *> $log
Select-String -Path $log -Pattern "error|FAILED|CMake Error" | Select-Object -First 30
```

If a step only says it exited with code 1 (like the install step in Error 4), run that step by hand to see the real message.

```powershell
$vs = "C:\Program Files\Microsoft Visual Studio\18\Community"
$cmake = "$vs\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
cd C:\dev\zedu-desktop\build\windows\x64
& $cmake -DBUILD_TYPE=Debug -P cmake_install.cmake 2>&1 | Select-Object -Last 25
```

## Messages safe to ignore

- Git line endings: `LF will be replaced by CRLF` is a reminder on generated Flutter files.
- `super_native_extensions`: `Get-Item : Could not find item ...\AppData` appeared in every run, including the one that worked.
- Rust: `rustc` and `cargo` not recognized did not stop the build, so Rust was not needed.

## Keeping generated files out of Git

Running the app rewrites generated files (`pubspec.lock` and the plugin registrant files). They show up in `git status` but are not part of your work.

```powershell
git status
git restore pubspec.lock windows linux macos
```

## Not verified

This guide was tested on one machine.

- Only `agora_rtc_engine` 6.5.4 was tested. Other plugin versions need names from `DownloadSDK.cmake`.
- Other Flutter and Visual Studio versions were not tested. The `Visual Studio\18\Community` path is only used for the manual install check.
- Google sign-in did not work locally. Use email and password if the login screen offers it, otherwise ask your team lead how contributors sign in. Do not edit login code to skip authentication.
- After launch, runtime exceptions appeared (uninitialized provider, `TextEditingController` used after being disposed, render overflow, duplicate GlobalKeys). They come from app code, not setup, and were not investigated. Run the target branch the same way to check whether they appear there too before assuming your change caused them.
