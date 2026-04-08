# Dependencies

This project uses Swift Package Manager (SPM) for third‑party dependencies. The app target `POCUS_Mentor` must link the following packages and products:

- Supabase Swift SDK
  - URL: https://github.com/supabase-community/supabase-swift
  - Product: `Supabase`
  - Version rule: Up to Next Major from 2.36.0 (or newer)

- TUSKit (tus.io resumable uploads)
  - URL: https://github.com/tus/TUSKit
  - Product: `TUSKit`
  - Version rule: Up to Next Major from 2.0.0 (or latest stable)

## Adding packages in Xcode

1) Add Supabase Swift
- Select the project in the navigator → Package Dependencies tab → `+`.
- Enter URL: `https://github.com/supabase-community/supabase-swift`
- Rule: Up to Next Major from 2.36.0
- Add the product `Supabase` to the `POCUS_Mentor` target.

2) Add TUSKit
- Package Dependencies tab → `+`.
- Enter URL: `https://github.com/tus/TUSKit`
- Rule: Up to Next Major from 2.0.0 (or latest stable)
- Add the product `TUSKit` to the `POCUS_Mentor` target.

3) Verify target linkage
- Target: `POCUS_Mentor` → General tab → Frameworks, Libraries, and Embedded Content
- Ensure both `Supabase` and `TUSKit` appear. If missing, click `+` to add them.

4) Resolve and clean
- File → Packages → Resolve Package Versions
- Product → (hold Option) Clean Build Folder…
- Build again.

## Why these packages are required

- `Supabase` is imported in multiple files (e.g., `SupabaseClientManager.swift`, `AuthService.swift`, `StorageService.swift`, `StudyService.swift`, `AppViewModel.swift`) and provides `SupabaseClient`, PostgREST builders, `Session`, and other types.
- `TUSKit` is imported in `UploadService.swift` and provides `TUSClient` and its delegate for background, resumable uploads.

## Troubleshooting

- Missing package product errors
  - Remove both packages from Package Dependencies and re‑add them.
  - File → Packages → Reset Package Caches (or delete `~/Library/Caches/org.swift.swiftpm`).
  - Delete Derived Data: `~/Library/Developer/Xcode/DerivedData`.
  - Quit and reopen Xcode, then Resolve Package Versions.

- Multiple targets/schemes
  - Ensure the `Supabase` and `TUSKit` products are added to every target that imports them. At minimum, the app target `POCUS_Mentor` must reference both products.

- Build still fails after adding packages
  - Confirm imports match product names exactly: `import Supabase` and `import TUSKit`.
  - Confirm no conflicting package versions in `Package.resolved`.
  - Make sure you’re opening the `.xcodeproj` or `.xcworkspace` consistently (don’t mix if using CocoaPods elsewhere).

## Command‑line (optional)

If you prefer to pre‑warm package resolution via command line:

