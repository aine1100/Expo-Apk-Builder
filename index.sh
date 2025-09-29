#!/bin/bash

# Expo APK Builder Script
# This script automates the process of building APK files locally for Expo apps

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect Android SDK location
detect_android_sdk() {
    local android_sdk_path=""
    
    # Check environment variables first
    if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
        android_sdk_path="$ANDROID_HOME"
    elif [ -n "$ANDROID_SDK_ROOT" ] && [ -d "$ANDROID_SDK_ROOT" ]; then
        android_sdk_path="$ANDROID_SDK_ROOT"
    else
        # Check common installation paths
        local common_paths=(
            "$HOME/Android/Sdk"
            "$HOME/Library/Android/sdk"
            "/usr/local/android-sdk"
            "/opt/android-sdk"
            "$HOME/AppData/Local/Android/Sdk"
            "C:/Users/$USER/AppData/Local/Android/Sdk"
        )
        
        for path in "${common_paths[@]}"; do
            if [ -d "$path" ]; then
                android_sdk_path="$path"
                break
            fi
        done
    fi
    
    # Verify the SDK path contains expected directories
    if [ -n "$android_sdk_path" ]; then
        if [ -d "$android_sdk_path/platform-tools" ] && [ -d "$android_sdk_path/build-tools" ]; then
            echo "$android_sdk_path"
            return 0
        fi
    fi
    
    return 1
}

# Function to validate Android tools
validate_android_tools() {
    local android_sdk_path="$1"
    local missing_tools=()
    local warnings=()
    
    # Check for adb
    if [ -n "$android_sdk_path" ] && [ -f "$android_sdk_path/platform-tools/adb" ]; then
        # adb found in SDK
        :
    elif command_exists adb; then
        # adb found in PATH
        :
    else
        missing_tools+=("adb (Android Debug Bridge)")
    fi
    
    # Check for build-tools directory and contents
    if [ -n "$android_sdk_path" ] && [ -d "$android_sdk_path/build-tools" ]; then
        local build_tools_versions=($(ls "$android_sdk_path/build-tools" 2>/dev/null | sort -V -r))
        if [ ${#build_tools_versions[@]} -eq 0 ]; then
            missing_tools+=("Android build-tools")
        else
            local latest_version="${build_tools_versions[0]}"
            local build_tools_path="$android_sdk_path/build-tools/$latest_version"
            
            # Check for essential build tools
            if [ ! -f "$build_tools_path/aapt" ] && [ ! -f "$build_tools_path/aapt2" ]; then
                missing_tools+=("aapt/aapt2 (Android Asset Packaging Tool)")
            fi
            
            if [ ! -f "$build_tools_path/zipalign" ]; then
                missing_tools+=("zipalign")
            fi
        fi
    else
        missing_tools+=("Android build-tools directory")
    fi
    
    # Check for Gradle (can be wrapper or system installation)
    local has_gradle=false
    if [ -f "./gradlew" ]; then
        has_gradle=true
    elif command_exists gradle; then
        has_gradle=true
    fi
    
    if [ "$has_gradle" = false ]; then
        missing_tools+=("Gradle (gradle command or ./gradlew wrapper)")
    fi
    
    # Check Java JDK compatibility
    if command_exists java; then
        local java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
        local java_major_version=$(echo "$java_version" | cut -d'.' -f1)
        
        # Handle Java version format differences (1.8.x vs 11.x)
        if [[ "$java_version" == 1.* ]]; then
            java_major_version=$(echo "$java_version" | cut -d'.' -f2)
        fi
        
        if [ "$java_major_version" -lt 8 ]; then
            missing_tools+=("Java JDK 8+ (current: Java $java_version)")
        elif [ "$java_major_version" -gt 17 ]; then
            warnings+=("Java $java_version detected. Android builds work best with Java 8-17")
        fi
    else
        missing_tools+=("Java JDK 8+")
    fi
    
    # Check for javac (JDK vs JRE)
    if command_exists java && ! command_exists javac; then
        warnings+=("Java Runtime (JRE) detected, but Java Development Kit (JDK) is recommended for Android builds")
    fi
    
    # Return results
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "MISSING:${missing_tools[*]}"
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "WARNINGS:${warnings[*]}"
    fi
    
    return 0
}

# Function to detect Xcode installation
detect_xcode() {
    # First check if we're on macOS
    if [[ "$(uname -s)" != "Darwin" ]]; then
        return 1
    fi
    
    # Check if Xcode command line tools are installed
    if ! command_exists xcode-select; then
        return 1
    fi
    
    # Check if Xcode developer directory is set
    local xcode_path
    xcode_path=$(xcode-select -p 2>/dev/null)
    local xcode_select_result=$?
    
    if [ $xcode_select_result -ne 0 ] || [ -z "$xcode_path" ]; then
        return 1
    fi
    
    # Verify the Xcode path exists and contains expected directories
    if [ ! -d "$xcode_path" ]; then
        return 1
    fi
    
    # Check for essential Xcode components
    if [ ! -d "$xcode_path/Platforms" ] || [ ! -d "$xcode_path/Toolchains" ]; then
        return 1
    fi
    
    # Check if iOS SDK is available
    if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
        return 1
    fi
    
    echo "$xcode_path"
    return 0
}

# Function to validate iOS tools
validate_ios_tools() {
    local xcode_path="$1"
    local missing_tools=()
    local warnings=()
    
    # Check for xcodebuild
    if ! command_exists xcodebuild; then
        missing_tools+=("xcodebuild (Xcode build tool)")
    else
        # Check Xcode version
        local xcode_version=$(xcodebuild -version 2>/dev/null | head -n 1 | sed 's/Xcode //')
        if [ -n "$xcode_version" ]; then
            # Extract major version number
            local major_version=$(echo "$xcode_version" | cut -d'.' -f1)
            if [ "$major_version" -lt 12 ]; then
                warnings+=("Xcode $xcode_version detected. Xcode 12+ recommended for modern iOS development")
            fi
        fi
    fi
    
    # Check for xcrun
    if ! command_exists xcrun; then
        missing_tools+=("xcrun (Xcode command line utility)")
    else
        # Verify iOS SDK availability
        if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
            missing_tools+=("iOS SDK (install through Xcode)")
        fi
        
        # Check iOS Simulator SDK
        if ! xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
            warnings+=("iOS Simulator SDK not found (recommended for testing)")
        fi
    fi
    
    # Check for CocoaPods
    if ! command_exists pod; then
        missing_tools+=("CocoaPods (install with: sudo gem install cocoapods)")
    else
        # Check CocoaPods version
        local pod_version=$(pod --version 2>/dev/null)
        if [ -n "$pod_version" ]; then
            # Extract major.minor version
            local pod_major=$(echo "$pod_version" | cut -d'.' -f1)
            local pod_minor=$(echo "$pod_version" | cut -d'.' -f2)
            
            # Check if version is too old (< 1.10)
            if [ "$pod_major" -lt 1 ] || ([ "$pod_major" -eq 1 ] && [ "$pod_minor" -lt 10 ]); then
                warnings+=("CocoaPods $pod_version detected. Version 1.10+ recommended")
            fi
        fi
    fi
    
    # Check for git (required by CocoaPods)
    if ! command_exists git; then
        missing_tools+=("git (required by CocoaPods)")
    fi
    
    # Check command line tools license agreement
    if ! xcrun clang --version >/dev/null 2>&1; then
        missing_tools+=("Xcode command line tools license (run: sudo xcodebuild -license accept)")
    fi
    
    # Check for iOS deployment target compatibility
    if command_exists xcrun; then
        local ios_sdk_version=$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null)
        if [ -n "$ios_sdk_version" ]; then
            local sdk_major=$(echo "$ios_sdk_version" | cut -d'.' -f1)
            if [ "$sdk_major" -lt 13 ]; then
                warnings+=("iOS SDK $ios_sdk_version detected. iOS 13+ SDK recommended")
            fi
        fi
    fi
    
    # Return results
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "MISSING:${missing_tools[*]}"
        return 1
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "WARNINGS:${warnings[*]}"
    fi
    
    return 0
}

# Function to check iOS prerequisites
check_ios_prerequisites() {
    print_status "Checking iOS build prerequisites..."
    
    # Check if running on macOS
    if [[ "$(uname -s)" != "Darwin" ]]; then
        print_error "iOS builds require macOS!"
        print_error "Current platform: $(uname -s)"
        print_error ""
        print_error "iOS development is only supported on macOS due to Apple's licensing requirements."
        print_error "To build iOS apps, you need:"
        print_error "1. A Mac computer running macOS"
        print_error "2. Xcode installed from the Mac App Store"
        print_error "3. iOS SDK and command line tools"
        return 1
    fi
    
    # Detect Xcode installation
    local xcode_path
    xcode_path=$(detect_xcode)
    local xcode_detection_result=$?
    
    if [ $xcode_detection_result -ne 0 ]; then
        print_error "Xcode not found or not properly configured!"
        print_error "Please install and configure Xcode:"
        print_error ""
        print_error "1. Install Xcode from the Mac App Store"
        print_error "2. Launch Xcode and accept the license agreement"
        print_error "3. Install additional components when prompted"
        print_error "4. Install command line tools:"
        print_error "   xcode-select --install"
        print_error "5. Set Xcode developer directory:"
        print_error "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        print_error ""
        print_error "After installation, verify with:"
        print_error "   xcodebuild -version"
        print_error "   xcrun --sdk iphoneos --show-sdk-path"
        return 1
    fi
    
    print_success "Xcode found at: $xcode_path"
    
    # Validate iOS tools
    local validation_result
    validation_result=$(validate_ios_tools "$xcode_path")
    local validation_exit_code=$?
    
    if [ $validation_exit_code -ne 0 ]; then
        local missing_tools=$(echo "$validation_result" | grep "^MISSING:" | cut -d':' -f2-)
        print_error "Missing required iOS tools:"
        IFS=' ' read -ra tools_array <<< "$missing_tools"
        for tool in "${tools_array[@]}"; do
            print_error "  - $tool"
        done
        print_error ""
        print_error "To fix these issues:"
        print_error "1. Open Xcode and install missing components"
        print_error "2. For CocoaPods: sudo gem install cocoapods"
        print_error "3. Accept Xcode license: sudo xcodebuild -license accept"
        print_error "4. Install command line tools: xcode-select --install"
        return 1
    fi
    
    # Show warnings if any
    if [[ "$validation_result" == WARNINGS:* ]]; then
        local warnings=$(echo "$validation_result" | grep "^WARNINGS:" | cut -d':' -f2-)
        IFS=' ' read -ra warnings_array <<< "$warnings"
        for warning in "${warnings_array[@]}"; do
            print_warning "$warning"
        done
    fi
    
    print_success "iOS build prerequisites satisfied!"
    return 0
}

# Function to check Android prerequisites
check_android_prerequisites() {
    print_status "Checking Android build prerequisites..."
    
    # Detect Android SDK
    local android_sdk_path
    android_sdk_path=$(detect_android_sdk)
    local sdk_detection_result=$?
    
    if [ $sdk_detection_result -ne 0 ]; then
        print_error "Android SDK not found!"
        print_error "Please install Android SDK and set up environment variables:"
        print_error ""
        print_error "1. Download Android Studio from: https://developer.android.com/studio"
        print_error "2. Install Android SDK through Android Studio"
        print_error "3. Set environment variable:"
        print_error "   export ANDROID_HOME=/path/to/android/sdk"
        print_error "   export ANDROID_SDK_ROOT=\$ANDROID_HOME"
        print_error ""
        print_error "Common SDK locations:"
        print_error "   Linux/macOS: ~/Android/Sdk or ~/Library/Android/sdk"
        print_error "   Windows: %LOCALAPPDATA%\\Android\\Sdk"
        return 1
    fi
    
    print_success "Android SDK found at: $android_sdk_path"
    
    # Validate Android tools
    local validation_result
    validation_result=$(validate_android_tools "$android_sdk_path")
    local validation_exit_code=$?
    
    if [ $validation_exit_code -ne 0 ]; then
        local missing_tools=$(echo "$validation_result" | grep "^MISSING:" | cut -d':' -f2-)
        print_error "Missing required Android tools:"
        IFS=' ' read -ra tools_array <<< "$missing_tools"
        for tool in "${tools_array[@]}"; do
            print_error "  - $tool"
        done
        print_error ""
        print_error "To fix these issues:"
        print_error "1. Open Android Studio"
        print_error "2. Go to Tools > SDK Manager"
        print_error "3. Install missing components in SDK Tools tab"
        print_error "4. For Java JDK: download from https://adoptium.net/"
        return 1
    fi
    
    # Show warnings if any
    if [[ "$validation_result" == WARNINGS:* ]]; then
        local warnings=$(echo "$validation_result" | grep "^WARNINGS:" | cut -d':' -f2-)
        IFS=' ' read -ra warnings_array <<< "$warnings"
        for warning in "${warnings_array[@]}"; do
            print_warning "$warning"
        done
    fi
    
    print_success "Android build prerequisites satisfied!"
    return 0
}

# Function to check native prerequisites for both platforms
check_native_prerequisites() {
    local platform="$1"  # "android", "ios", or "both"
    local android_ok=false
    local ios_ok=false
    
    case "$platform" in
        "android")
            if check_android_prerequisites; then
                android_ok=true
            fi
            ;;
        "ios")
            if check_ios_prerequisites; then
                ios_ok=true
            fi
            ;;
        "both")
            print_status "Checking prerequisites for both platforms..."
            if check_android_prerequisites; then
                android_ok=true
            else
                print_warning "Android prerequisites not satisfied"
            fi
            
            if check_ios_prerequisites; then
                ios_ok=true
            else
                print_warning "iOS prerequisites not satisfied"
            fi
            
            if [ "$android_ok" = false ] && [ "$ios_ok" = false ]; then
                print_error "Neither Android nor iOS prerequisites are satisfied!"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Function to load native build configuration
load_native_config() {
    local platform="$1"
    local profile="$2"
    
    # Check if eas.json exists and has native configuration
    if [ -f "eas.json" ]; then
        # For now, use default configuration
        # In a full implementation, this would parse eas.json for native build settings
        print_status "Using default native build configuration for $platform"
    else
        print_status "No eas.json found, using default native build configuration"
    fi
}

# Function to setup Android signing
setup_android_signing() {
    local build_profile="$1"
    local keystore_path=""
    
    # For debug builds, use debug keystore
    if [[ "$build_profile" == "debug" ]] || [[ "$build_profile" == "development" ]]; then
        print_status "Using debug keystore for $build_profile build"
        return 0
    fi
    
    # For release builds, check for release keystore
    local android_dir="./android"
    local keystore_dir="$android_dir/app"
    
    # Common keystore locations
    local keystore_locations=(
        "$keystore_dir/release.keystore"
        "$keystore_dir/app-release.keystore"
        "$keystore_dir/keystore/release.keystore"
        "./release.keystore"
    )
    
    for location in "${keystore_locations[@]}"; do
        if [ -f "$location" ]; then
            keystore_path="$location"
            break
        fi
    done
    
    if [ -z "$keystore_path" ]; then
        print_warning "No release keystore found. Creating debug keystore for release build."
        print_warning "For production builds, create a proper release keystore."
        return 0
    fi
    
    print_success "Found release keystore: $keystore_path"
    return 0
}

# Function to build Android natively
build_android_native() {
    local build_profile="$1"
    local output_dir="$2"
    
    print_status "Starting native Android build with profile: $build_profile"
    
    # Ensure we have the Android project
    if [ ! -d "android" ]; then
        print_status "Generating Android project..."
        expo prebuild --platform android --clean
    fi
    
    # Navigate to android directory
    cd android
    
    # Setup signing
    setup_android_signing "$build_profile"
    
    # Determine build type
    local gradle_task="assembleRelease"
    if [[ "$build_profile" == "debug" ]] || [[ "$build_profile" == "development" ]]; then
        gradle_task="assembleDebug"
    fi
    
    print_status "Running Gradle build: $gradle_task"
    
    # Run Gradle build
    if [ -f "./gradlew" ]; then
        ./gradlew clean $gradle_task
    elif command_exists gradle; then
        gradle clean $gradle_task
    else
        print_error "Neither ./gradlew nor gradle command found!"
        cd ..
        return 1
    fi
    
    local gradle_exit_code=$?
    cd ..
    
    if [ $gradle_exit_code -ne 0 ]; then
        print_error "Gradle build failed!"
        return 1
    fi
    
    # Find and organize the APK
    local apk_path=""
    if [[ "$gradle_task" == "assembleDebug" ]]; then
        apk_path=$(find android/app/build/outputs/apk/debug -name "*.apk" | head -1)
    else
        apk_path=$(find android/app/build/outputs/apk/release -name "*.apk" | head -1)
    fi
    
    if [ -z "$apk_path" ]; then
        print_error "APK not found after build!"
        return 1
    fi
    
    # Create output directory and copy APK
    mkdir -p "$output_dir/android"
    local final_apk="$output_dir/android/app-$build_profile.apk"
    cp "$apk_path" "$final_apk"
    
    print_success "Android APK created: $final_apk"
    
    # Generate build info
    local apk_size=$(stat -f%z "$final_apk" 2>/dev/null || stat -c%s "$final_apk" 2>/dev/null || echo "unknown")
    cat > "$output_dir/android/build-info.json" << EOF
{
  "platform": "android",
  "buildType": "$build_profile",
  "buildTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "artifactPath": "$final_apk",
  "fileSize": $apk_size,
  "buildMethod": "native"
}
EOF
    
    echo "$final_apk"
    return 0
}

# Function to setup iOS signing
setup_ios_signing() {
    local build_profile="$1"
    
    print_status "Setting up iOS code signing for $build_profile build"
    
    # For now, use automatic signing
    # In a full implementation, this would handle provisioning profiles and certificates
    print_status "Using automatic code signing"
    
    return 0
}

# Function to build iOS natively
build_ios_native() {
    local build_profile="$1"
    local output_dir="$2"
    
    print_status "Starting native iOS build with profile: $build_profile"
    
    # Ensure we have the iOS project
    if [ ! -d "ios" ]; then
        print_status "Generating iOS project..."
        expo prebuild --platform ios --clean
    fi
    
    # Navigate to ios directory
    cd ios
    
    # Install CocoaPods dependencies
    if [ -f "Podfile" ]; then
        print_status "Installing CocoaPods dependencies..."
        pod install
        if [ $? -ne 0 ]; then
            print_error "CocoaPods installation failed!"
            cd ..
            return 1
        fi
    fi
    
    # Setup signing
    setup_ios_signing "$build_profile"
    
    # Find the workspace or project file
    local build_target=""
    if [ -f *.xcworkspace ]; then
        build_target=$(ls *.xcworkspace | head -1)
        build_target="-workspace $build_target"
    elif [ -f *.xcodeproj ]; then
        build_target=$(ls *.xcodeproj | head -1)
        build_target="-project $build_target"
    else
        print_error "No Xcode workspace or project found!"
        cd ..
        return 1
    fi
    
    # Determine configuration
    local configuration="Release"
    if [[ "$build_profile" == "debug" ]] || [[ "$build_profile" == "development" ]]; then
        configuration="Debug"
    fi
    
    # Get the scheme name (usually the project name)
    local scheme_name=$(basename *.xcodeproj .xcodeproj 2>/dev/null || echo "YourApp")
    
    print_status "Building iOS app with configuration: $configuration"
    
    # Build for device
    xcodebuild -scheme "$scheme_name" \
               $build_target \
               -configuration "$configuration" \
               -destination "generic/platform=iOS" \
               -archivePath "./build/$scheme_name.xcarchive" \
               archive
    
    if [ $? -ne 0 ]; then
        print_error "iOS build failed!"
        cd ..
        return 1
    fi
    
    # Export IPA
    local export_plist="./export.plist"
    cat > "$export_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string></string>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
               -archivePath "./build/$scheme_name.xcarchive" \
               -exportPath "./build/export" \
               -exportOptionsPlist "$export_plist"
    
    local export_exit_code=$?
    cd ..
    
    if [ $export_exit_code -ne 0 ]; then
        print_error "iOS export failed!"
        return 1
    fi
    
    # Find and organize the IPA
    local ipa_path=$(find ios/build/export -name "*.ipa" | head -1)
    
    if [ -z "$ipa_path" ]; then
        print_error "IPA not found after build!"
        return 1
    fi
    
    # Create output directory and copy IPA
    mkdir -p "$output_dir/ios"
    local final_ipa="$output_dir/ios/app-$build_profile.ipa"
    cp "$ipa_path" "$final_ipa"
    
    print_success "iOS IPA created: $final_ipa"
    
    # Generate build info
    local ipa_size=$(stat -f%z "$final_ipa" 2>/dev/null || stat -c%s "$final_ipa" 2>/dev/null || echo "unknown")
    cat > "$output_dir/ios/build-info.json" << EOF
{
  "platform": "ios",
  "buildType": "$build_profile",
  "buildTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "artifactPath": "$final_ipa",
  "fileSize": $ipa_size,
  "buildMethod": "native"
}
EOF
    
    echo "$final_ipa"
    return 0
}

# Function to build both platforms natively
build_native_both() {
    local build_profile="$1"
    local output_dir="$2"
    
    print_status "Starting native builds for both Android and iOS"
    
    local android_success=false
    local ios_success=false
    local android_artifact=""
    local ios_artifact=""
    
    # Check prerequisites for both platforms
    if ! check_native_prerequisites "both"; then
        print_error "Prerequisites check failed for native builds"
        return 1
    fi
    
    # Build Android
    print_status "Building Android..."
    if check_android_prerequisites >/dev/null 2>&1; then
        if android_artifact=$(build_android_native "$build_profile" "$output_dir"); then
            android_success=true
            print_success "Android build completed successfully"
        else
            print_error "Android build failed"
        fi
    else
        print_warning "Skipping Android build - prerequisites not met"
    fi
    
    # Build iOS (only on macOS)
    print_status "Building iOS..."
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if check_ios_prerequisites >/dev/null 2>&1; then
            if ios_artifact=$(build_ios_native "$build_profile" "$output_dir"); then
                ios_success=true
                print_success "iOS build completed successfully"
            else
                print_error "iOS build failed"
            fi
        else
            print_warning "Skipping iOS build - prerequisites not met"
        fi
    else
        print_warning "Skipping iOS build - macOS required"
    fi
    
    # Generate build summary
    generate_build_report "$output_dir" "$android_success" "$ios_success" "$android_artifact" "$ios_artifact"
    
    # Return success if at least one platform built successfully
    if [ "$android_success" = true ] || [ "$ios_success" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to organize artifacts
organize_artifacts() {
    local platform="$1"
    local build_path="$2"
    local output_dir="$3"
    
    # This function is called by the individual build functions
    # Artifacts are already organized in the build functions
    print_status "Artifacts organized in: $output_dir"
}

# Function to generate build report
generate_build_report() {
    local output_dir="$1"
    local android_success="$2"
    local ios_success="$3"
    local android_artifact="$4"
    local ios_artifact="$5"
    
    local report_file="$output_dir/build-summary.json"
    
    cat > "$report_file" << EOF
{
  "buildTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "buildMethod": "native",
  "platforms": {
    "android": {
      "success": $android_success,
      "artifact": "$android_artifact"
    },
    "ios": {
      "success": $ios_success,
      "artifact": "$ios_artifact"
    }
  }
}
EOF
    
    print_success "Build report generated: $report_file"
}

# Function to generate platform-specific setup commands
generate_android_setup_commands() {
    local os_type="$1"
    
    case "$os_type" in
        "Darwin")  # macOS
            echo "# Android SDK Setup Commands for macOS:"
            echo "# 1. Install Android Studio:"
            echo "brew install --cask android-studio"
            echo ""
            echo "# 2. Set environment variables (add to ~/.zshrc or ~/.bash_profile):"
            echo "export ANDROID_HOME=\$HOME/Library/Android/sdk"
            echo "export ANDROID_SDK_ROOT=\$ANDROID_HOME"
            echo "export PATH=\$PATH:\$ANDROID_HOME/emulator"
            echo "export PATH=\$PATH:\$ANDROID_HOME/tools"
            echo "export PATH=\$PATH:\$ANDROID_HOME/tools/bin"
            echo "export PATH=\$PATH:\$ANDROID_HOME/platform-tools"
            ;;
        "Linux")
            echo "# Android SDK Setup Commands for Linux:"
            echo "# 1. Download Android Studio:"
            echo "# Visit: https://developer.android.com/studio"
            echo ""
            echo "# 2. Set environment variables (add to ~/.bashrc or ~/.zshrc):"
            echo "export ANDROID_HOME=\$HOME/Android/Sdk"
            echo "export ANDROID_SDK_ROOT=\$ANDROID_HOME"
            echo "export PATH=\$PATH:\$ANDROID_HOME/emulator"
            echo "export PATH=\$PATH:\$ANDROID_HOME/tools"
            echo "export PATH=\$PATH:\$ANDROID_HOME/tools/bin"
            echo "export PATH=\$PATH:\$ANDROID_HOME/platform-tools"
            ;;
        "Windows"|"MINGW"*|"CYGWIN"*|"MSYS"*)
            echo "# Android SDK Setup Commands for Windows:"
            echo "# 1. Download Android Studio:"
            echo "# Visit: https://developer.android.com/studio"
            echo ""
            echo "# 2. Set environment variables:"
            echo "setx ANDROID_HOME \"%LOCALAPPDATA%\\Android\\Sdk\""
            echo "setx ANDROID_SDK_ROOT \"%ANDROID_HOME%\""
            echo "setx PATH \"%PATH%;%ANDROID_HOME%\\emulator;%ANDROID_HOME%\\tools;%ANDROID_HOME%\\platform-tools\""
            ;;
        *)
            echo "# Generic Android SDK Setup:"
            echo "# 1. Install Android Studio from: https://developer.android.com/studio"
            echo "# 2. Set ANDROID_HOME environment variable to SDK location"
            echo "# 3. Add SDK tools to PATH"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    if ! command_exists node; then
        print_error "Node.js is not installed. Please install Node.js first."
        exit 1
    fi
    
    # Check npm/yarn
    if ! command_exists npm && ! command_exists yarn; then
        print_error "Neither npm nor yarn is installed. Please install one of them."
        exit 1
    fi
    
    # Check Expo CLI
    if ! command_exists expo; then
        print_warning "Expo CLI not found. Installing globally..."
        if command_exists yarn; then
            yarn global add @expo/cli
        else
            npm install -g @expo/cli
        fi
    fi
    
    # Check EAS CLI
    if ! command_exists eas; then
        print_warning "EAS CLI not found. Installing globally..."
        if command_exists yarn; then
            yarn global add @expo/eas-cli
        else
            npm install -g @expo/eas-cli
        fi
    fi
    
    # Check for bundletool (needed for AAB to APK conversion)
    if ! command_exists bundletool; then
        print_warning "bundletool not found. Checking for Java..."
        if ! command_exists java; then
            print_warning "Java not found. You'll need Java to convert AAB to APK."
            print_status "Please install Java JDK 8+ from: https://adoptium.net/"
        else
            print_status "Java found. bundletool will be downloaded automatically if needed."
        fi
    fi
    
    print_success "Prerequisites check completed!"
}

# Function to setup EAS if not configured
setup_eas() {
    if [ ! -f "eas.json" ]; then
        print_status "EAS not configured. Setting up EAS..."
        eas build:configure
        print_success "EAS configuration created!"
    else
        print_status "EAS already configured."
    fi
}

# Function to login to EAS
login_eas() {
    print_status "Checking EAS authentication..."
    if ! eas whoami >/dev/null 2>&1; then
        print_warning "Not logged in to EAS. Please login:"
        eas login
    else
        print_success "Already logged in to EAS as $(eas whoami)"
    fi
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing/updating dependencies..."
    
    # Windows-specific fixes
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        print_warning "Windows detected. Applying Windows-specific fixes..."
        
        # Kill any running Node processes
        taskkill //f //im node.exe 2>/dev/null || true
        taskkill //f //im npm.exe 2>/dev/null || true
        
        # Clear npm cache
        npm cache clean --force 2>/dev/null || true
        
        # Try to remove problematic node_modules if it exists
        if [ -d "node_modules" ]; then
            print_status "Attempting to clean node_modules..."
            rm -rf node_modules 2>/dev/null || {
                print_warning "Could not remove node_modules automatically."
                print_warning "Please run as administrator or manually delete node_modules folder"
                read -p "Press Enter after deleting node_modules folder manually, or Ctrl+C to exit..."
            }
        fi
    fi
    
    # Install dependencies with retry mechanism
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Installation attempt $attempt of $max_attempts..."
        
        if [ -f "yarn.lock" ]; then
            if yarn install; then
                break
            fi
        elif [ -f "package-lock.json" ]; then
            if npm install --no-optional; then
                break
            fi
        else
            print_warning "No lock file found. Using npm install..."
            if npm install --no-optional; then
                break
            fi
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Failed to install dependencies after $max_attempts attempts"
            print_error "Try running as administrator or manually delete node_modules"
            exit 1
        fi
        
        print_warning "Installation failed, retrying in 5 seconds..."
        sleep 5
        ((attempt++))
    done
    
    print_success "Dependencies installed!"
}

# Function to prebuild if needed
prebuild_app() {
    if [ ! -d "android" ]; then
        print_status "Android directory not found. Running prebuild..."
        expo prebuild --platform android
        print_success "Prebuild completed!"
    else
        print_status "Android directory exists. Skipping prebuild."
    fi
}

# Function to download bundletool if needed
download_bundletool() {
    local bundletool_dir="$HOME/.expo/bundletool"
    local bundletool_jar="$bundletool_dir/bundletool.jar"
    local bundletool_url="https://github.com/google/bundletool/releases/latest/download/bundletool-all-1.15.6.jar"
    
    if [ ! -f "$bundletool_jar" ]; then
        print_status "Downloading bundletool..."
        mkdir -p "$bundletool_dir"
        
        if command_exists curl; then
            curl -L -o "$bundletool_jar" "$bundletool_url"
        elif command_exists wget; then
            wget -O "$bundletool_jar" "$bundletool_url"
        else
            print_error "Neither curl nor wget found. Please download bundletool manually."
            print_error "Download from: $bundletool_url"
            print_error "Save to: $bundletool_jar"
            exit 1
        fi
        
        if [ $? -eq 0 ]; then
            print_success "bundletool downloaded successfully!"
        else
            print_error "Failed to download bundletool"
            exit 1
        fi
    fi
    
    echo "$bundletool_jar"
}

# Function to convert AAB to APK
convert_aab_to_apk() {
    local aab_file="$1"
    local output_dir="$2"
    
    if [ ! -f "$aab_file" ]; then
        print_error "AAB file not found: $aab_file"
        return 1
    fi
    
    print_status "Converting AAB to APK..."
    
    # Download bundletool if needed
    local bundletool_jar=$(download_bundletool)
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Generate APKs from AAB
    local apks_file="$output_dir/app.apks"
    java -jar "$bundletool_jar" build-apks \
        --bundle="$aab_file" \
        --output="$apks_file" \
        --mode=universal
    
    if [ $? -ne 0 ]; then
        print_error "Failed to generate APKs from AAB"
        return 1
    fi
    
    # Extract universal APK
    local temp_dir="$output_dir/temp_apks"
    mkdir -p "$temp_dir"
    
    if command_exists unzip; then
        unzip -q "$apks_file" -d "$temp_dir"
    else
        print_error "unzip command not found. Cannot extract APK from APKS archive."
        return 1
    fi
    
    # Find and copy the universal APK
    local universal_apk=$(find "$temp_dir" -name "universal.apk" | head -1)
    if [ -n "$universal_apk" ]; then
        local final_apk="$output_dir/app-universal.apk"
        cp "$universal_apk" "$final_apk"
        
        # Clean up temp files
        rm -rf "$temp_dir"
        rm -f "$apks_file"
        
        print_success "APK created: $final_apk"
        return 0
    else
        print_error "Universal APK not found in generated APKs"
        return 1
    fi
}
# Function to build AAB via cloud and convert to APK
build_aab_to_apk() {
    local build_profile=${1:-preview}
    
    print_status "Building AAB via cloud and converting to APK..."
    print_status "This will use EAS cloud build to create AAB, then convert locally"
    
    # Start cloud build for AAB
    print_status "Starting cloud AAB build with profile: $build_profile"
    eas build --platform android --profile $build_profile
    
    if [ $? -ne 0 ]; then
        print_error "AAB build submission failed!"
        exit 1
    fi
    
    print_success "AAB build submitted successfully!"
    print_status "Once the build completes, download the AAB file and use:"
    print_status "$0 --convert-aab path/to/your/app.aab"
    print_status ""
    print_status "Or download it automatically when ready and convert:"
    print_warning "Manual download and conversion required for now."
    print_status "Check your email or visit https://expo.dev for the download link."
}

build_apk_cloud() {
    local build_profile=${1:-preview}
    
    print_status "Starting cloud APK build with profile: $build_profile"
    print_status "This will use EAS cloud build (10-20 minutes)"
    print_status "You can monitor progress at: https://expo.dev"
    
    # Start cloud build
    eas build --platform android --profile $build_profile
    
    if [ $? -eq 0 ]; then
        print_success "Build submitted successfully!"
        print_status "Your APK will be available for download once the build completes."
        print_status "Check your email or visit https://expo.dev for the download link."
    else
        print_error "Build submission failed!"
        exit 1
    fi
}

# Function to build APK locally
build_apk_local() {
    local build_profile=${1:-preview}
    
    # Check platform support
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
        print_error "Local Android builds are not supported on Windows!"
        print_error "Use --cloud option or run this script on macOS/Linux"
        exit 1
    fi
    
    print_status "Starting local APK build with profile: $build_profile"
    print_status "This may take several minutes..."
    
    # Start local build
    eas build --platform android --profile $build_profile --local
    
    if [ $? -eq 0 ]; then
        print_success "APK build completed successfully!"
        
        # Try to find the generated APK
        if [ -d "dist" ]; then
            apk_file=$(find dist -name "*.apk" | head -1)
            if [ -n "$apk_file" ]; then
                print_success "APK file created: $apk_file"
            fi
        fi
    else
        print_error "APK build failed!"
        exit 1
    fi
}

# Function to build APK
build_apk() {
    local build_profile=${1:-preview}
    local use_cloud=false
    
    # Check if running on Windows (local builds not supported)
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
        print_warning "Windows detected. Local Android builds are not supported on Windows."
        print_status "Switching to EAS cloud build..."
        use_cloud=true
    fi
    
    print_status "Starting APK build with profile: $build_profile"
    
    if [ "$use_cloud" = true ]; then
        print_status "Using EAS cloud build (this may take 10-20 minutes)..."
        print_status "You can monitor progress at: https://expo.dev/accounts/[your-username]/projects/[your-project]/builds"
        
        # Start cloud build
        eas build --platform android --profile $build_profile
        
        if [ $? -eq 0 ]; then
            print_success "Build submitted successfully!"
            print_status "Your APK will be available for download once the build completes."
            print_status "Check your email or visit https://expo.dev for the download link."
        else
            print_error "Build submission failed!"
            exit 1
        fi
    else
        print_status "Using local build (this may take several minutes)..."
        
        # Start local build
        eas build --platform android --profile $build_profile --local
        
        if [ $? -eq 0 ]; then
            print_success "APK build completed successfully!"
            
            # Try to find the generated APK
            if [ -d "dist" ]; then
                apk_file=$(find dist -name "*.apk" | head -1)
                if [ -n "$apk_file" ]; then
                    print_success "APK file created: $apk_file"
                fi
            fi
        else
            print_error "APK build failed!"
            exit 1
        fi
    fi
}

# Function to show help
show_help() {
    echo "Expo APK Builder Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --profile PROFILE    Build profile to use (default: preview)"
    echo "  -s, --skip-deps         Skip dependency installation (deprecated, use --no-install)"
    echo "  --no-install            Skip dependency installation completely"
    echo "  -c, --cloud             Force cloud build (get APK download link)"
    echo "  -l, --local             Force local build (macOS/Linux only)"
    echo "  -a, --aab-to-apk        Build AAB via cloud, convert to APK locally (Windows-friendly)"
    echo "  --convert-aab PATH      Convert existing AAB file to APK"
    echo "  --native-android        Build Android APK using native Android SDK and Gradle"
    echo "  --native-ios            Build iOS IPA using native Xcode and iOS SDK (macOS only)"
    echo "  --native-both           Build both Android and iOS using native toolchains"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Auto-detect platform and build accordingly"
    echo "  $0 -p production        # Build with production profile"
    echo "  $0 --no-install         # Skip node_modules installation completely"
    echo "  $0 --cloud              # Force cloud build (get download link)"
    echo "  $0 --local              # Force local build (macOS/Linux)"
    echo "  $0 --aab-to-apk         # Build AAB via cloud, convert to APK (Windows)"
    echo "  $0 --convert-aab app.aab # Convert existing AAB to APK"
    echo "  $0 --native-android     # Build Android APK using native SDK"
    echo "  $0 --native-ios         # Build iOS IPA using Xcode (macOS only)"
    echo "  $0 --native-both        # Build both platforms using native tools"
    echo "  $0 -p production --no-install # Production build without installing deps"
    echo ""
    echo "Dependency Management:"
    echo "  --no-install: Completely skip npm/yarn install (fastest)"
    echo "  --skip-deps:  Legacy alias for --no-install"
    echo ""
    echo "Build Methods:"
    echo "  --cloud:         Use EAS cloud build service (all platforms)"
    echo "  --local:         Use EAS local build (macOS/Linux only)"
    echo "  --aab-to-apk:    Build AAB via cloud, convert to APK locally"
    echo "  --native-android: Use native Android SDK and Gradle (all platforms)"
    echo "  --native-ios:    Use native Xcode and iOS SDK (macOS only)"
    echo "  --native-both:   Use native toolchains for both platforms"
    echo ""
    echo "Platform Support:"
    echo "  Windows: Use --cloud, --aab-to-apk, or --native-android options"
    echo "  macOS/Linux: All options supported"
}

# Main function
main() {
    local build_profile="preview"
    local skip_deps=false
    local force_cloud=false
    local force_local=false
    local aab_to_apk=false
    local convert_aab_path=""
    local native_android=false
    local native_ios=false
    local native_both=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                build_profile="$2"
                shift 2
                ;;
            -s|--skip-deps|--no-install)
                skip_deps=true
                if [[ "$1" == "--no-install" ]]; then
                    print_status "Using --no-install flag (recommended over --skip-deps)"
                fi
                shift
                ;;
            -c|--cloud)
                force_cloud=true
                shift
                ;;
            -l|--local)
                force_local=true
                shift
                ;;
            -a|--aab-to-apk)
                aab_to_apk=true
                shift
                ;;
            --convert-aab)
                convert_aab_path="$2"
                shift 2
                ;;
            --native-android)
                native_android=true
                shift
                ;;
            --native-ios)
                native_ios=true
                shift
                ;;
            --native-both)
                native_both=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check for conflicting options
    local option_count=0
    [ "$force_cloud" = true ] && ((option_count++))
    [ "$force_local" = true ] && ((option_count++))
    [ "$aab_to_apk" = true ] && ((option_count++))
    [ "$native_android" = true ] && ((option_count++))
    [ "$native_ios" = true ] && ((option_count++))
    [ "$native_both" = true ] && ((option_count++))
    [ -n "$convert_aab_path" ] && ((option_count++))
    
    if [ $option_count -gt 1 ]; then
        print_error "Cannot use multiple build method options simultaneously"
        print_error "Choose only one of: --cloud, --local, --aab-to-apk, --native-android, --native-ios, --native-both, --convert-aab"
        exit 1
    fi
    
    # Handle AAB conversion only
    if [ -n "$convert_aab_path" ]; then
        print_status "Converting AAB to APK..."
        local output_dir="./apk_output"
        if convert_aab_to_apk "$convert_aab_path" "$output_dir"; then
            print_success "Conversion completed! APK: $output_dir/app-universal.apk"
        else
            print_error "Conversion failed!"
            exit 1
        fi
        return
    fi
    
    print_status "Starting Expo build process..."
    
    # For native builds, skip EAS setup
    local skip_eas=false
    if [ "$native_android" = true ] || [ "$native_ios" = true ] || [ "$native_both" = true ]; then
        skip_eas=true
        print_status "Using native build method - skipping EAS setup"
    fi
    
    # Run the build process
    if [ "$skip_eas" = false ]; then
        check_prerequisites
        login_eas
        setup_eas
    else
        # For native builds, only check basic prerequisites
        if ! command_exists node; then
            print_error "Node.js is not installed. Please install Node.js first."
            exit 1
        fi
        
        if ! command_exists expo; then
            print_warning "Expo CLI not found. Installing globally..."
            if command_exists yarn; then
                yarn global add @expo/cli
            else
                npm install -g @expo/cli
            fi
        fi
    fi
    
    # Handle dependency installation
    if [ "$skip_deps" = true ]; then
        print_warning "Skipping dependency installation (--no-install flag used)"
        print_status "Assuming node_modules are already up to date..."
        
        # Basic check to ensure node_modules exists
        if [ ! -d "node_modules" ]; then
            print_error "node_modules directory not found!"
            print_error "Either run without --no-install flag or manually install dependencies first:"
            print_error "  npm install  # or yarn install"
            exit 1
        fi
        
        print_success "Using existing node_modules"
    else
        install_dependencies
    fi
    
    # For native builds, prebuild is handled within the build functions
    if [ "$skip_eas" = false ]; then
        prebuild_app
    fi
    
    # Choose build method
    if [ "$native_android" = true ]; then
        # Native Android build
        if ! check_android_prerequisites; then
            print_error "Android prerequisites not satisfied!"
            exit 1
        fi
        
        load_native_config "android" "$build_profile"
        local output_dir="./builds"
        
        if build_android_native "$build_profile" "$output_dir"; then
            print_success "Native Android build completed successfully!"
        else
            print_error "Native Android build failed!"
            exit 1
        fi
        
    elif [ "$native_ios" = true ]; then
        # Native iOS build
        if ! check_ios_prerequisites; then
            print_error "iOS prerequisites not satisfied!"
            exit 1
        fi
        
        load_native_config "ios" "$build_profile"
        local output_dir="./builds"
        
        if build_ios_native "$build_profile" "$output_dir"; then
            print_success "Native iOS build completed successfully!"
        else
            print_error "Native iOS build failed!"
            exit 1
        fi
        
    elif [ "$native_both" = true ]; then
        # Native builds for both platforms
        load_native_config "both" "$build_profile"
        local output_dir="./builds"
        
        if build_native_both "$build_profile" "$output_dir"; then
            print_success "Native builds completed!"
        else
            print_error "Native builds failed!"
            exit 1
        fi
        
    elif [ "$aab_to_apk" = true ]; then
        build_aab_to_apk "$build_profile"
    elif [ "$force_cloud" = true ]; then
        build_apk_cloud "$build_profile"
    elif [ "$force_local" = true ]; then
        build_apk_local "$build_profile"
    else
        build_apk "$build_profile"
    fi
    
    print_success "Build process completed!"
}

# Trap to handle interruption
trap 'print_error "Build process interrupted!"; exit 1' INT

# Run main function with all arguments
main "$@"