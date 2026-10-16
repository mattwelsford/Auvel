# Accounts and credentials checklist

Things only Matt can do (C8). Each is listed in the order it unblocks work.

| Code | Step | Unblocks | When |
|---|---|---|---|
| AC1 | Run both apps on your own Mac and iPhone with Xcode's free Personal Team ([hardware-test.md](phase-3/hardware-test.md)). | G3 recording | Now. No membership needed. |
| AC2 | Enrol in the Apple Developer Program as an **individual** at developer.apple.com/programs/enroll. Needs an Apple Account with two-factor authentication and photo ID through the Apple Developer app. Annual fee: US$99 or the local equivalent. Approval usually takes one to two days. | AC3 to AC7 | Before P6. Start soon, because Apple sets the timing. |
| AC3 | Request the user-assigned device name entitlement (`com.apple.developer.device-information.user-assigned-device-name`) from the developer account's capability request form. Reason to give: the Mac companion shows which of the user's iPhones are paired and connected. | F15 | After AC2. Apple decides. |
| AC4 | Register the App IDs `nz.co.touchbase.auvel` and `nz.co.touchbase.auvel.mac`. | TestFlight, Developer ID | After AC2 |
| AC5 | Create a **Developer ID Application** certificate and an App Store Connect API key for notarisation. Store both as GitHub encrypted secrets (names listed at P6). | Signed, notarised Mac releases (A1) | P6 |
| AC6 | Generate the Sparkle EdDSA key pair with Sparkle's `generate_keys`. Keep the private key offline and in a GitHub secret. | Auto-update (ADR-006) | P6 |
| AC7 | Create the App Store Connect record, US$4.99 price, "Data Not Collected" label. | A3 | P6 |
| AC8 | Buy getauvel.com (and auvel.net) and file the US trademark (R11). | Website, brand protection | Before launch |

The App Store seller name and the name macOS shows for the Mac app's developer will be **Matt Welsford**, because the membership is individual. Bundle IDs can stay `nz.co.touchbase.*`. They do not have to match the account holder.
