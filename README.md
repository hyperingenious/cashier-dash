# Cashier Dash (Flutter)

Restaurant cashier dashboard app built with Flutter.

## Features

- Cashier login screen
- Dashboard with tabs for:
  - Tables management
  - Menu management
  - Billing overview
- Create restaurant tables (name + capacity)
- Create menu items (name + category + price)
- Add orders to a selected table
- Generate a bill (subtotal, tax, total)
- Settle bill and free table

## Run

1. Install Flutter SDK and verify:
   - `flutter --version`
2. From project root:
   - `flutter pub get`
   - `flutter run`

## Notes

- Data is currently in-memory for fast prototyping.
- You can connect this to SQLite, Firebase, or a backend API in the next step.
