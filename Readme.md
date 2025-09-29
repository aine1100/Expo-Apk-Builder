# Expo APK Builder Script

A comprehensive script for building Android APKs and iOS IPAs from Expo projects using multiple build methods including native toolchains.

## 🚀 Features

- **Multiple Build Methods**: EAS Cloud, EAS Local, Native Android SDK, Native Xcode
- **Cross-Platform Support**: Windows, macOS, and Linux
- **Automatic Prerequisites Detection**: Validates required tools and SDKs
- **Flexible Configuration**: Support for multiple build profiles
- **AAB to APK Conversion**: Convert Android App Bundles to APKs locally
- **Comprehensive Error Handling**: Detailed error messages and troubleshooting guides

## 📋 Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Build Methods](#build-methods)
- [Prerequisites](#prerequisites)
- [Usage Examples](#usage-examples)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Platform Support](#platform-support)

## 🛠 Installation

1. **Download the script**:
   ```bash
   curl -O https://raw.githubusercontent.com/your-repo/expo-apk-builder/main/index.sh
   chmod +x index.sh
   ```

2. **Make it executable**:
   ```bash
   chmod +x index.sh
   ```

3. **Run from your Expo project directory**:
   ```bash
   ./index.sh
   ```

## ⚡ Quick Start

```bash
# Basic APK build (auto-detects best method for your platform)
./index.sh

# Build with specific profile
./index.sh -p production

# Native Android build (fastest, works on all platforms)
./index.sh --native-android

# Native iOS build (macOS only)
./index.sh --native-ios

# Build both platforms natively
./index.sh --native-both
```

## 🏗 Build Methods

### 1. Native Android Build (`--native-android`)
**Recommended for Android development**

Uses Android SDK and Gradle directly for fastest builds.

**Advantages**:
- ✅ Works on Windows, macOS, and Linux
- ✅ Fastest build times (5-10 minutes)
- ✅ Full control over build process
- ✅ No cloud dependencies
- ✅ Works offline

**Requirements**:
- Android SDK
- Java JDK 8+
- Gradle (or Gradle wrapper)

### 2. Native iOS Build (`--native-ios`)
**Recommended for iOS development**

Uses Xcode and iOS SDK directly for complete control.

**Advantages**:
- ✅ Full Xcode integration
- ✅ Native code signing
- ✅ Complete iOS toolchain access
- ✅ No cloud dependencies

**Requirements**:
- macOS only
- Xcode 12+
- iOS SDK
- CocoaPods
- Command Line Tools

### 3. Native Both Platforms (`--native-both`)
**Recommended for cross-platform development**

Builds both Android and iOS using native toolchains.

**Behavior**:
- Checks prerequisites for both platforms
- Builds Android first, then iOS
- Continues with available platforms if one fails
- Generates comprehensive build report

### 4. EAS Cloud Build (`--cloud`)
**Good for CI/CD and complex builds**

Uses Expo's cloud build service.

**Advantages**:
- ✅ Works on any platform
- ✅ Handles complex native dependencies
- ✅ Professional build environment

**Disadvantages**:
- ❌ Requires internet connection
- ❌ Slower (10-20 minutes)
- ❌ Requires EAS account

### 5. EAS Local Build (`--local`)
**Good for advanced users**

Uses EAS build system locally.

**Limitations**:
- ❌ Not supported on Windows
- ❌ Requires Docker setup
- ❌ Complex configuration

### 6. AAB to APK Conversion (`--aab-to-apk`)
**Windows-friendly option**

Builds AAB via cloud, converts to APK locally.

**Use Case**:
- Windows users who need APK files
- When Play Store AAB is not suitable

## 📦 Prerequisites

### For Native Android Builds

#### Automatic Detection
The script automatically detects Android SDK in common locations:
- `$ANDROID_HOME`
- `$ANDROID_SDK_ROOT`
- `~/Android/Sdk` (Linux/macOS)
- `~/Library/Android/sdk` (macOS)
- `%LOCALAPPDATA%\Android\Sdk` (Windows)

#### Required Tools
- **Android SDK**: Install via Android Studio
- **Java JDK 8-17**: Download from [Adoptium](https://adoptium.net/)
- **Gradle**: Usually included with project (`./gradlew`)
- **Build Tools**: Install via Android Studio SDK Manager

#### Setup Commands

**macOS**:
```bash
# Install Android Studio
brew install --cask android-studio

# Set environment variables (add to ~/.zshrc)
export ANDROID_HOME=$HOME/Library/Android/sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

**Linux**:
```bash
# Download Android Studio from https://developer.android.com/studio

# Set environment variables (add to ~/.bashrc)
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

**Windows**:
```cmd
# Download Android Studio from https://developer.android.com/studio

# Set environment variables
setx ANDROID_HOME "%LOCALAPPDATA%\Android\Sdk"
setx ANDROID_SDK_ROOT "%ANDROID_HOME%"
setx PATH "%PATH%;%ANDROID_HOME%\emulator;%ANDROID_HOME%\tools;%ANDROID_HOME%\platform-tools"
```

### For Native iOS Builds

#### Required Tools (macOS only)
- **Xcode 12+**: Install from Mac App Store
- **iOS SDK**: Included with Xcode
- **Command Line Tools**: `xcode-select --install`
- **CocoaPods**: `sudo gem install cocoapods`

#### Setup Commands
```bash
# Install Xcode from Mac App Store, then:

# Install command line tools
xcode-select --install

# Set Xcode developer directory
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Accept license
sudo xcodebuild -license accept

# Install CocoaPods
sudo gem install cocoapods

# Verify installation
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-path
```

## 💡 Usage Examples

### Basic Usage

```bash
# Auto-detect platform and build method
./index.sh

# Build with production profile
./index.sh -p production

# Skip dependency installation (if already installed)
./index.sh --no-install
```

### Native Builds

```bash
# Android native build (recommended)
./index.sh --native-android

# iOS native build (macOS only)
./index.sh --native-ios

# Both platforms natively
./index.sh --native-both

# Native build with custom profile
./index.sh --native-android -p release
```

### Cloud Builds

```bash
# Force cloud build
./index.sh --cloud

# Cloud build with production profile
./index.sh --cloud -p production
```

### AAB Conversion

```bash
# Build AAB via cloud, convert to APK
./index.sh --aab-to-apk

# Convert existing AAB file
./index.sh --convert-aab path/to/app.aab
```

### Advanced Usage

```bash
# Production build without dependencies installation
./index.sh -p production --no-install --native-android

# Debug build for both platforms
./index.sh -p debug --native-both
```

## ⚙️ Configuration

### Build Profiles

The script uses EAS build profiles from `eas.json`. Common profiles:

- `preview`: Development builds with debugging
- `production`: Release builds for distribution
- `debug`: Debug builds with full debugging info

### Native Build Configuration

For native builds, the script uses sensible defaults:

**Android**:
- Debug builds: `assembleDebug`
- Release builds: `assembleRelease`
- Automatic keystore handling
- Gradle wrapper preferred

**iOS**:
- Debug builds: Debug configuration
- Release builds: Release configuration
- Automatic code signing
- CocoaPods dependency management

### Output Structure

Native builds organize artifacts in a standardized structure:

```
builds/
├── android/
│   ├── app-preview.apk
│   └── build-info.json
├── ios/
│   ├── app-preview.ipa
│   └── build-info.json
└── build-summary.json
```

## 🔧 Troubleshooting

### Common Android Issues

**"Android SDK not found"**
```bash
# Check environment variables
echo $ANDROID_HOME
echo $ANDROID_SDK_ROOT

# Set manually if needed
export ANDROID_HOME=/path/to/android/sdk
```

**"Gradle build failed"**
```bash
# Clean and rebuild
cd android
./gradlew clean
./gradlew assembleRelease
```

**"Java version incompatible"**
```bash
# Check Java version
java -version

# Install compatible JDK (8-17)
# Download from https://adoptium.net/
```

### Common iOS Issues

**"Xcode not found"**
```bash
# Install command line tools
xcode-select --install

# Set Xcode path
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Verify
xcodebuild -version
```

**"CocoaPods installation failed"**
```bash
# Update CocoaPods
sudo gem install cocoapods

# Clear cache and reinstall
cd ios
rm -rf Pods Podfile.lock
pod install
```

**"Code signing failed"**
```bash
# Check certificates
security find-identity -v -p codesigning

# Use automatic signing in Xcode
# Or configure manual signing with proper profiles
```

### General Issues

**"Command not found"**
- Ensure all required tools are installed
- Check PATH environment variable
- Restart terminal after installing tools

**"Permission denied"**
```bash
# Make script executable
chmod +x index.sh

# On Windows, run as Administrator if needed
```

**"Build artifacts not found"**
- Check build logs for errors
- Ensure build completed successfully
- Verify output directory permissions

## 🖥 Platform Support

| Feature | Windows | macOS | Linux |
|---------|---------|-------|-------|
| Native Android | ✅ | ✅ | ✅ |
| Native iOS | ❌ | ✅ | ❌ |
| EAS Cloud | ✅ | ✅ | ✅ |
| EAS Local | ❌ | ✅ | ✅ |
| AAB Conversion | ✅ | ✅ | ✅ |

### Platform-Specific Notes

**Windows**:
- Native Android builds fully supported
- iOS builds require macOS (Apple requirement)
- Use `--native-android` or `--cloud` options
- PowerShell and CMD both supported

**macOS**:
- All build methods supported
- Best platform for cross-platform development
- Native iOS builds only available here

**Linux**:
- Native Android builds fully supported
- iOS builds not possible (Apple limitation)
- Good for Android-focused development

## 📝 Command Reference

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `-p, --profile` | Build profile | `./index.sh -p production` |
| `--no-install` | Skip dependency installation | `./index.sh --no-install` |
| `--native-android` | Native Android build | `./index.sh --native-android` |
| `--native-ios` | Native iOS build | `./index.sh --native-ios` |
| `--native-both` | Native builds for both | `./index.sh --native-both` |
| `--cloud` | Force cloud build | `./index.sh --cloud` |
| `--local` | Force local build | `./index.sh --local` |
| `--aab-to-apk` | Build AAB, convert to APK | `./index.sh --aab-to-apk` |
| `--convert-aab` | Convert existing AAB | `./index.sh --convert-aab app.aab` |
| `-h, --help` | Show help | `./index.sh --help` |

### Build Profiles

Common profiles you can use with `-p` option:

- `preview` (default): Development builds
- `production`: Release builds for stores
- `debug`: Debug builds with symbols
- `development`: Development builds with debugging

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on multiple platforms
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Verify your [Prerequisites](#prerequisites)
3. Run with verbose output: `bash -x ./index.sh`
4. Open an issue with full error logs

## 🔄 Updates

To update the script:

```bash
# Download latest version
curl -O https://raw.githubusercontent.com/your-repo/expo-apk-builder/main/index.sh
chmod +x index.sh
```

---

**Happy Building! 🚀**