# Expo APK Builder Script

A bash script that automates the process of building APK files locally for Expo applications, eliminating common issues and streamlining the build workflow.

## 🚀 Features

- **Automated Prerequisites Check** - Verifies all required tools and dependencies
- **Smart Dependency Management** - Detects and uses yarn or npm automatically
- **EAS Integration** - Handles EAS CLI setup and authentication seamlessly
- **Local Building** - Builds APK files locally without cloud dependencies
- **Error Handling** - Comprehensive error detection and user-friendly messages
- **Colored Output** - Clear, colored terminal output for better visibility
- **Flexible Profiles** - Support for different build profiles (preview, production, etc.)
- **Cross-Platform** - Works on macOS, Linux, and Windows (with WSL/Git Bash)

## 📋 Prerequisites

Before using this script, ensure you have:

- **Node.js** (v16 or higher)
- **npm** or **yarn** package manager
- **Git** (for cloning and version control)
- An **Expo account** (free registration at expo.dev)
- **Android development environment** (if building locally)

> **Note:** The script will automatically install Expo CLI and EAS CLI if they're missing.

## 🛠 Installation

1. **Download the script** to your Expo project root directory:
   ```bash
   # Option 1: Copy the script content and save as index.sh
   # Option 2: Download directly (if hosted)
   curl -o index.sh [script-url]
   ```

2. **Make the script executable**:
   ```bash
   chmod +x index.sh
   ```

3. **Verify installation**:
   ```bash
   ./index.sh --help
   ```

## 📖 Usage

### Basic Usage

```bash
# Build APK with default settings
./index.sh
```

### Advanced Usage

```bash
# Build with specific profile
./index.sh --profile production

# Skip dependency installation (faster if deps are up-to-date)
./index.sh --skip-deps

# Combine options
./index.sh --profile staging --skip-deps
```

### Command Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--profile` | `-p` | Build profile to use | `preview` |
| `--skip-deps` | `-s` | Skip dependency installation | `false` |
| `--help` | `-h` | Show help message | - |

## 🔧 Configuration

### EAS Build Profiles

The script uses EAS build profiles defined in `eas.json`. Common profiles include:

```json
{
  "build": {
    "preview": {
      "android": {
        "buildType": "apk"
      }
    },
    "production": {
      "android": {
        "buildType": "apk"
      }
    }
  }
}
```

### First-Time Setup

When running the script for the first time:

1. **EAS Login**: You'll be prompted to log in to your Expo account
2. **EAS Configuration**: The script will create `eas.json` if it doesn't exist
3. **Prebuild**: Android project files will be generated if needed

## 📁 Output

After a successful build, you'll find your APK file in:
- `dist/` directory (most common)
- Project root directory
- Path displayed in the success message

## 🐛 Troubleshooting

### Common Issues and Solutions

#### "No Expo configuration file found"
```bash
# Ensure you're in the project root directory
ls -la app.json app.config.js app.config.ts
```

#### "Node.js is not installed"
```bash
# Install Node.js from nodejs.org or using a package manager
# macOS: brew install node
# Ubuntu: sudo apt install nodejs npm
```

#### "Build failed" errors
```bash
# Check your app.json/app.config.js configuration
# Ensure all required fields are present:
# - name, slug, version, orientation, icon, etc.
```

#### Memory issues during build
```bash
# Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=4096"
./index.sh
```

#### Android SDK issues
```bash
# Ensure Android SDK is properly configured
# Set ANDROID_HOME environment variable
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

### Debug Mode

For additional debugging information, run with verbose output:
```bash
set -x  # Enable debug mode
./index.sh
set +x  # Disable debug mode
```

## 🔄 Workflow Integration

### Git Hooks

Add to `.git/hooks/pre-push`:
```bash
#!/bin/bash
echo "Building APK before push..."
./index.sh --skip-deps
```

### CI/CD Integration

For GitHub Actions:
```yaml
- name: Build APK
  run: |
    chmod +x index.sh
    ./index.sh --profile production
```

## 📝 Build Profiles Guide

### Preview Profile (Default)
- **Purpose**: Testing and development
- **Optimization**: Minimal
- **Size**: Larger file size
- **Build Time**: Faster

### Production Profile
- **Purpose**: App store releases
- **Optimization**: Full optimization
- **Size**: Smaller file size
- **Build Time**: Slower

### Custom Profiles
Create custom profiles in `eas.json`:
```json
{
  "build": {
    "staging": {
      "android": {
        "buildType": "apk",
        "developmentClient": false
      }
    }
  }
}
```

## 🚨 Security Notes

- **API Keys**: Never commit sensitive API keys to version control
- **Environment Variables**: Use environment variables for sensitive data
- **Build Logs**: Review build logs for exposed sensitive information

## 📊 Performance Tips

1. **Skip Dependencies**: Use `--skip-deps` when dependencies haven't changed
2. **Local Cache**: Keep `node_modules` and build cache between builds
3. **Profile Selection**: Use `preview` profile for development builds
4. **Incremental Builds**: EAS supports incremental builds for faster subsequent builds

## 🤝 Contributing

To improve this script:

1. **Fork** the repository
2. **Create** a feature branch
3. **Test** your changes thoroughly
4. **Submit** a pull request

## 📜 License

This script is provided as-is under the MIT License. See LICENSE file for details.

## 🆘 Support

- **Expo Documentation**: [docs.expo.dev](https://docs.expo.dev)
- **EAS Build Guide**: [docs.expo.dev/build/introduction](https://docs.expo.dev/build/introduction)
- **Community Forum**: [forums.expo.dev](https://forums.expo.dev)

## 📈 Version History

- **v1.0.0**: Initial release with basic APK building functionality
- **v1.1.0**: Added build profile support and improved error handling
- **v1.2.0**: Enhanced dependency management and colored output

---

**Happy Building! 🎉**

> Made with ❤️ for the Expo community