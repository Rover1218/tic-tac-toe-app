# Google Play Store Setup Guide

## Pre-Publication Checklist

### 1. **Create Keystore for App Signing**
```bash
# Navigate to android folder
cd android

# Generate keystore (replace with your details)
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Create key.properties file
cp key.properties.example key.properties
# Edit key.properties with your keystore details
```

### 2. **Build Release APK/AAB**
```bash
# Clean and build
flutter clean
flutter pub get

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Or build APK
flutter build apk --release
```

### 3. **Play Store Requirements Completed** ✅

- **App Name**: "Tic Tac Toe Classic"
- **Package Name**: `com.tictactoe.classic`
- **Version**: 1.0.0 (Version Code: 1)
- **Target SDK**: 34 (Android 14)
- **Min SDK**: 21 (Android 5.0)
- **Permissions**: Minimal (Internet, Wake Lock)
- **Privacy Policy**: Created ✅
- **Terms of Service**: Created ✅
- **ProGuard Rules**: Configured ✅
- **Release Optimization**: Enabled ✅

### 4. **Play Store Console Setup**

1. **Create Developer Account** ($25 one-time fee)
2. **Upload App Bundle** (`build/app/outputs/bundle/release/app-release.aab`)
3. **Fill Store Listing**:
   - **Title**: "Tic Tac Toe Classic"
   - **Short Description**: "Classic Tic Tac Toe with AI opponents and beautiful animations"
   - **Full Description**: Use the description from pubspec.yaml
   - **Category**: Games > Puzzle
   - **Content Rating**: Everyone
   - **Privacy Policy URL**: Upload PRIVACY_POLICY.md to your website
   - **Screenshots**: Take 2-8 screenshots of gameplay

### 5. **App Content Declarations**
- **Target Audience**: Everyone
- **Content Rating**: ESRB Everyone, PEGI 3
- **Ads**: No (free app without ads)
- **In-App Purchases**: No
- **Data Safety**: No data collected

### 6. **Release Process**
1. Upload signed AAB
2. Complete store listing
3. Submit for review
4. Review typically takes 1-3 days

## Important Notes

- **First Release**: Use internal testing first
- **Updates**: Increment version code for each release
- **Signing**: Keep keystore file secure and backed up
- **Testing**: Test on multiple devices before release

## File Locations
- **Release AAB**: `build/app/outputs/bundle/release/app-release.aab`
- **Release APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Privacy Policy**: `PRIVACY_POLICY.md`
- **Terms**: `TERMS_OF_SERVICE.md`
