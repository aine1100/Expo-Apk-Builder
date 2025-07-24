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

# Function to build APK with cloud
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
    echo "  -s, --skip-deps         Skip dependency installation"
    echo "  -c, --cloud             Force cloud build (useful for Windows)"
    echo "  -l, --local             Force local build (macOS/Linux only)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Build with default settings (auto-detects platform)"
    echo "  $0 -p production        # Build with production profile"
    echo "  $0 --cloud              # Force cloud build (Windows users)"
    echo "  $0 --local              # Force local build (macOS/Linux users)"
    echo "  $0 --skip-deps          # Skip dependency installation"
}

# Main function
main() {
    local build_profile="preview"
    local skip_deps=false
    local force_cloud=false
    local force_local=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                build_profile="$2"
                shift 2
                ;;
            -s|--skip-deps)
                skip_deps=true
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
    if [ "$force_cloud" = true ] && [ "$force_local" = true ]; then
        print_error "Cannot use both --cloud and --local options simultaneously"
        exit 1
    fi
    
    print_status "Starting Expo APK build process..."
    
    # Run the build process
    check_prerequisites
    login_eas
    setup_eas
    
    if [ "$skip_deps" = false ]; then
        install_dependencies
    fi
    
    prebuild_app
    
    # Override build type if forced
    if [ "$force_cloud" = true ]; then
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