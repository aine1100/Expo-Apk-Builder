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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if we're in an Expo project
    if [ ! -f "app.json" ] && [ ! -f "app.config.js" ] && [ ! -f "app.config.ts" ]; then
        print_error "No Expo configuration file found. Make sure you're in an Expo project directory."
        exit 1
    fi
    
    # Check Node.js
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
    echo "  $0 -p production --no-install # Production build without installing deps"
    echo ""
    echo "Dependency Management:"
    echo "  --no-install: Completely skip npm/yarn install (fastest)"
    echo "  --skip-deps:  Legacy alias for --no-install"
    echo ""
    echo "Platform Support:"
    echo "  Windows: Use --cloud or --aab-to-apk options"
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
    [ -n "$convert_aab_path" ] && ((option_count++))
    
    if [ $option_count -gt 1 ]; then
        print_error "Cannot use multiple build method options simultaneously"
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
    
    print_status "Starting Expo APK build process..."
    
    # Run the build process
    check_prerequisites
    login_eas
    setup_eas
    
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
    
    prebuild_app
    
    # Choose build method
    if [ "$aab_to_apk" = true ]; then
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