# Cleaning Ninja

A lightweight phone cleaner app for Android built with Flutter.

## Features

- 🧹 Scan and delete cache files
- 📁 Clean temporary files and junk
- 🗑️ Remove empty folders
- 📊 Display junk size in MB
- 🎨 Clean, minimal Material Design UI
- ✅ Works on Android 7 to Android 14
- 🔒 No root required - safe and legal operations only

## What Gets Cleaned

Cleaning Ninja scans and removes:

1. **Manage Apps**: Helps you delete app caches and uninstall apps you don't need anymore.
2. **App Support Files**: Temporary data in app support directory
3. **Download Folder**: Junk files in Downloads
4. **Thumbnail Caches**: Hidden thumbnail folders in Pictures and DCIM
5. **Junk File Extensions**: .tmp, .log, .bak, .cache files
6. **Empty Folders**: Unused empty directories
7. **Optimizes Memory**: cleans out apps memory cache, removes temporary files

## Installation

1. Make sure you have Flutter 3+ installed
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Connect an Android device or start an emulator
5. Run `flutter run`

## Permissions

The app requests the following permissions:

- **READ_EXTERNAL_STORAGE** (Android < 13)
- **WRITE_EXTERNAL_STORAGE** (Android < 13)
- **MANAGE_EXTERNAL_STORAGE** (Android 11+)
- **READ_MEDIA_*** (Android 13+)

These permissions are required to scan and clean files outside the app's private directory.

## Usage

1. Tap **"Scan Phone"** to analyze your device
2. Wait for the scan to complete
3. Review the amount of junk found
4. Tap **"Clean Now"** to delete junk files
5. Enjoy your cleaned phone!

## Technical Details

- **Framework**: Flutter 3+
- **Language**: Dart with null safety
- **Minimum SDK**: Android 7.0 (API 24)
- **Target SDK**: Android 14 (API 34)

## Dependencies

- `permission_handler`: Handle runtime permissions
- `path_provider`: Access app directories
- `intl`: Format numbers and sizes

## Project Structure

```
lib/
├── main.dart                          # Main app entry and UI
└── services/
    └── junk_cleaner_service.dart      # Core cleaning logic
```

## Safety

Cleaning Ninja only accesses files that are:
- Created by the app itself
- In public storage directories (with user permission)
- Safe to delete without affecting system stability

The app will never:
- Require root access
- Delete system files
- Access private app data from other apps
- Perform any harmful operations

## License

This project is provided as-is for educational purposes.
