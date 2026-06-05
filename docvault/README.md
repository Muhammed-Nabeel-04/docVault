# DocVault 🛡️

**DocVault** is a high-security, offline-first document vault built with Flutter. It is designed for users who prioritize privacy and want to keep their sensitive documents (IDs, contracts, medical records) encrypted and accessible only to them, with zero cloud dependency.

## Key Features

- **🔒 Military-Grade Encryption:** All documents are encrypted using **AES-GCM (v1)**.
- **📱 Biometric Authentication:** Secure access using Fingerprint or Face ID (Biometric-first).
- **🔢 PIN Fallback:** SHA-256 salted PIN hashing with constant-time equality for secure fallback.
- **🕒 Expiry Reminders:** Get notified before your important documents (passports, insurance) expire.
- **📂 Offline-First:** No data ever leaves your device. Total privacy by design.
- **📑 Multi-File Support:** Attach multiple pages or related files to a single document entry.
- **🌓 Adaptive Theme:** Clean, modern UI that respects system dark/light modes.

## Technical Stack

- **Framework:** Flutter (3.0+)
- **Database:** SQLite (via `sqflite`) with self-healing logic for physical corruption.
- **Security:** 
  - `flutter_secure_storage` for key management.
  - `encrypt` (AES-GCM) for document content.
  - `local_auth` for biometric integration.
- **State Management:** Riverpod.
- **Licensing:** Syncfusion Flutter components (for high-performance PDF viewing).

## Getting Started

### Prerequisites

- Flutter SDK
- Android Studio / VS Code
- A valid Syncfusion License Key (passed during build)

### Development

Run the project in development mode:

```bash
run_dev.bat
```

### Production Build

To generate a signed production APK, ensure your `key.properties` and `SYNCFUSION_KEY.txt` are configured, then run:

```bash
build_prod.bat
```

## Security Disclosure

DocVault is strictly offline. We do not have servers, and we never collect your data. Security is maintained through local encryption and biometric gates. If you lose your PIN and your biometric data is unavailable, your data cannot be recovered.

## Privacy Policy

The official Privacy Policy can be found [here](https://muhammed-nabeel-04.github.io/docVault/).

---

*Built with ❤️ for privacy and security.*
