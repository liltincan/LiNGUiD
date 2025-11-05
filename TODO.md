# TODO: Address App Store Rejection Issues

## Tasks
- [x] Update Resources/Info.plist to add NSLocationWhenInUseUsageDescription explaining location use for specifying dialectal and language variety information.
- [x] Modify Services/StoreKitManager.swift to add server-side receipt validation by sending receipts to the backend /validateReceipt endpoint, handling production vs sandbox retries.
- [x] Edit Views/TermsOfServiceView.swift to add a "Subscriptions" section with required details for auto-renewable subscriptions.
- [x] Create Services/ReceiptValidator.swift to handle receipt fetching and backend validation for GetProView.
- [x] Advise on App Store Connect: Set Support URL to https://learnwithlinguid.com/support and Terms of Use to https://learnwithlinguid.com/terms-of-service.

## Followup Steps
- [ ] Test IAP flows in sandbox and production environments to ensure receipt validation works.
- [ ] Verify location permission prompt displays the updated purpose string.
- [ ] Submit updated app for review and monitor for approval.
