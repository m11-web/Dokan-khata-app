# Hamza Poultry Khata

Offline-first Flutter ledger for poultry supply deliveries made by vehicles
3152 and 6540. Customer accounts, day settings and entries are stored locally
in SQLite; no account or network connection is required.

## Included workflows

- Lock a working date and maintain its supply rate and per-vehicle farm loads.
- Record each shopkeeper's two vehicle weights, cash received, Naga status and
  optional daily Less override in the daily sheet.
- Recalculate customer balances chronologically from the opening balance and
  saved dated entries.
- Add, edit, activate/deactivate and reorder customer profiles.
- Review saved dates, daily totals and historical receipts.
- Render Urdu receipts, monthly statements, daily Roznamcha sheets and
  multi-bill A4 pages as PNGs at 3x scale; share or print the generated images.
- Export and restore a JSON backup using the device's file picker.

Generated documents use the bundled Noto Naskh Arabic and Inter fonts. PNG
exports are saved through the Android system file picker; shared PNGs are kept
in the app's private export directory.

## Build

With Flutter and Android SDK configured:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The Android application ID is `com.hamzapoultry.khata`. The current Flutter SDK
sets the app minimum to API 24, above the requested API 23 floor.
