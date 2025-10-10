# TODO: Fix App Store Review Issues

## 1. Update Info.plist for Location Purpose String ✅
- Edit `NSLocationWhenInUseUsageDescription` to provide a clear, specific example of how location is used.

## 2. Fix IAP Receipt Validation in ReceiptValidator.swift ✅
- Replace Firebase function call with direct HTTP POST to backend `/api/iap/validateReceipt`.
- Fetch and base64-encode receipt data from `Bundle.main.appStoreReceiptURL`.
- Include `uid` from FirebaseAuth in the request.
- Handle server response for validation result.

## 3. Update GetProView.swift for Server Validation ✅
- In `purchasePro()`, after transaction finish, fetch receipt and call updated `ReceiptValidator.shared.validateReceipt(receiptData: data, uid: uid)`.
- Update success/error handling based on server response.
- In `restorePurchases()`, add server validation after AppStore.sync().

## 4. Non-Code Followups
- Update website (https://learnwithlinguid.com) to include support information (e.g., FAQ, contact form).
- In App Store Connect: Add Terms of Use link to App Description; confirm Privacy Policy URL; ensure Paid Apps Agreement accepted.
- Test IAP in sandbox/TestFlight; rebuild and resubmit.
