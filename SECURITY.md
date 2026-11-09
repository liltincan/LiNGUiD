# Security

Use GitHub's [private vulnerability report form](https://github.com/liltincan/LiNGUiD/security/advisories/new). Include the affected version or commit, a minimal reproduction, and the potential impact. Redact API keys, tokens, and personal data. Do not post vulnerabilities in public issues or pull requests.

Keep service-account keys, signing keys, credentials, and user exports out of the repository. The Firebase client configuration identifies the app to Firebase; it is distinct from a service-account key. Access to backend data must be enforced by server-side authorization and Firebase Security Rules.
