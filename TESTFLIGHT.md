# TestFlight distribution for HEOS Remote

The app is distributed privately through TestFlight and is not intended to be submitted for public App Store review.

## Current upload candidate

- App: **HEOS Remote**
- Bundle ID: `se.anders.HEOSLocalRemote`
- Version: `0.3.0`
- Build: `3`
- Minimum iOS/iPadOS version: `17.0`
- Encryption declaration: no non-exempt encryption
- Languages: Swedish and English
- Multicast Networking: embedded and signed in the App Store provisioning profile
- Local IPA: `build/HEOS-Remote-0.3.0-build3.ipa`
- Local archive: `build/HEOS-Remote-0.3.0-build3.xcarchive`

The IPA and archive are local build artifacts and are intentionally excluded from Git.

## Apple Developer and App Store Connect preparation

1. Confirm that Multicast Networking is approved for the App ID `se.anders.HEOSLocalRemote`.
2. Let Xcode automatic signing create or download a distribution profile containing the multicast entitlement.
3. Create the **HEOS Remote** app record in App Store Connect using the bundle ID `se.anders.HEOSLocalRemote`.
4. Ensure that the version and build number are higher than the latest uploaded build.

Suggested values when creating the app record:

- Primary language: Swedish
- SKU: `heos-remote-ios`
- User access: Limited or Full, depending on the intended App Store Connect team

## Archive and upload

In Xcode, select **Any iOS Device (arm64)** and choose **Product > Archive**. In Organizer, select **Distribute App > TestFlight & App Store > Upload**.

`AppStoreConnectExportOptions.plist` creates a locally exported IPA for verification. `TestFlightExportOptions.plist` uses the `upload` destination and should be used only when a build is intentionally being sent to App Store Connect.

After the app record exists, open `build/HEOS-Remote-0.3.0-build3.xcarchive` in Xcode Organizer and select **Distribute App > TestFlight & App Store > Upload**. Alternatively, use `TestFlightExportOptions.plist` with `xcodebuild -exportArchive`.

Uploading a TestFlight build does not publish the app on the App Store. Internal testers can be added after Apple finishes processing the build. External testers require a separate TestFlight Beta App Review.
