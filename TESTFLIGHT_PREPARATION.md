# TestFlight Preparation Checklist

## ✅ Completed

1. **App Icon** - Installed in `Assets.xcassets/AppIcon.appiconset/`
   - All 18 required icon sizes are present
   - 1024x1024 marketing icon included

2. **Bundle Identifier** - `com.russellmiller.POCUS-Mentor`
   - Configured in project settings

3. **Development Team** - `7GX83T5H9X`
   - Set for automatic code signing

4. **Version & Build**
   - Marketing Version: 1.0
   - Current Project Version: 1
   - ⚠️ **Action Required**: Increment build number for each TestFlight upload

5. **Privacy Permissions**
   - Photo Library Usage: ✅ Configured
   - Photo Library Add Usage: ✅ Configured

6. **Supabase Configuration**
   - URL, keys, and bucket configured
   - Environment variables set

## 📋 Pre-Submission Checklist

### In Xcode

1. **Verify App Icon**
   - Open Xcode → Select project → General tab
   - Verify AppIcon appears in the App Icons section
   - All sizes should show checkmarks

2. **Update Build Number** (IMPORTANT)
   - In Xcode: Select project → General tab → Version section
   - Increment "Build" number (e.g., from 1 to 2)
   - Or use: `agvtool next-version -all` in terminal

3. **Verify Signing & Capabilities**
   - Select target → Signing & Capabilities tab
   - Ensure "Automatically manage signing" is checked
   - Verify Team: `7GX83T5H9X`
   - Verify Bundle Identifier: `com.russellmiller.POCUS-Mentor`

4. **Build Configuration**
   - Select "Any iOS Device" or a connected device
   - Ensure Release configuration is selected (not Debug)

5. **Archive the App**
   - Product → Archive
   - Wait for archive to complete
   - Window → Organizer will open

### In App Store Connect

1. **Create App Record** (if not exists)
   - Go to https://appstoreconnect.apple.com
   - My Apps → + (New App)
   - Fill in:
     - Platform: iOS
     - Name: POCUS Mentor (or your preferred name)
     - Primary Language: English
     - Bundle ID: `com.russellmiller.POCUS-Mentor`
     - SKU: `pocus-mentor-001` (or any unique identifier)

2. **App Information**
   - Category: Medical or Education
   - Privacy Policy URL: (required for TestFlight)
   - Support URL: (optional but recommended)

3. **TestFlight Setup**
   - Go to TestFlight tab in App Store Connect
   - Add Internal Testers (up to 100)
   - Add External Testers (requires Beta App Review)
   - Add Test Information:
     - What to Test: Brief description
     - Feedback Email: Your email

### Upload to TestFlight

1. **From Xcode Organizer**
   - Select your archive
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Choose "Upload"
   - Follow the wizard:
     - Distribution options: Upload
     - App Thinning: All compatible device variants
     - Re-sign if needed: Yes
   - Click "Upload"
   - Wait for processing (can take 10-60 minutes)

2. **Verify Upload**
   - Go to App Store Connect → TestFlight
   - Wait for "Processing" to complete
   - Check for any errors or warnings

3. **Add Build to TestFlight**
   - Once processing completes, select the build
   - Add to Internal Testing group
   - (Optional) Submit for External Testing (requires review)

## 🔧 Quick Commands

### Increment Build Number
```bash
cd /Users/russellmiller/Projects/POCUS_APP/POCUS_Mentor
agvtool next-version -all
```

### Check Current Version/Build
```bash
agvtool what-version
```

### Build for TestFlight (from terminal)
```bash
xcodebuild -workspace POCUS_Mentor.xcworkspace \
           -scheme POCUS_Mentor \
           -configuration Release \
           -archivePath build/POCUS_Mentor.xcarchive \
           archive
```

## ⚠️ Common Issues

1. **"No App Store Connect Access"**
   - Ensure you're added to the App Store Connect team
   - Check your Apple ID has the right permissions

2. **"Invalid Bundle Identifier"**
   - Verify bundle ID matches App Store Connect exactly
   - Check for typos or extra spaces

3. **"Missing Compliance"**
   - Export Compliance: Usually "No" for most apps
   - Encryption: Usually "No" unless using custom encryption

4. **"Processing Failed"**
   - Check email from App Store Connect for details
   - Common causes: Missing icons, invalid entitlements, code signing issues

5. **"Build Already Exists"**
   - Increment build number and rebuild
   - Each upload needs a unique build number

## 📝 TestFlight Metadata

### What to Test (Example)
```
This is the initial TestFlight build of POCUS Mentor. Please test:

1. User authentication and signup flow
2. Creating and submitting studies
3. Uploading media (images/videos)
4. Review workflow for attendings
5. Feedback system
6. All user roles (Fellow, Attending, Administrator)

Report any crashes, UI issues, or unexpected behavior.
```

### Feedback Email
- Use a dedicated email for TestFlight feedback
- Consider: `pocus-mentor-feedback@yourdomain.com`

## 🚀 Next Steps

1. ✅ App icon installed
2. ⏳ Increment build number
3. ⏳ Archive in Xcode
4. ⏳ Upload to App Store Connect
5. ⏳ Add testers
6. ⏳ Distribute build

## 📚 Resources

- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

---

**Current Configuration:**
- Bundle ID: `com.russellmiller.POCUS-Mentor`
- Version: 1.0
- Build: 1 (⚠️ increment before upload)
- Team: 7GX83T5H9X
- Deployment Target: iOS 17.0



