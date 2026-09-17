# Changelog

## 1.0.3

- Added exact scan filters for `deviceId`, `macAddress` and broadcast `name`.
- Added `BluetoothDeviceSnapshot.macAddress` for adapters that can expose a stable address.
- Added `BluetoothConnectionManager.scanAndConnect()` to scan by device identity or broadcast name and connect with one call.
- Updated demo and README examples for MAC/name based discovery and connection.

## 1.0.2

- Added runtime Bluetooth capability reporting for BLE, Classic SPP, MTU, RSSI, PHY, L2CAP, background scan and multi-connection support.
- Added structured Bluetooth logger hooks for scan, connect, state, packet and error diagnostics.
- Added RSSI threshold filtering for memory and Harmony scanner wrappers.
- Updated demo and README usage to show capability reporting, logging and stronger scan filtering.
- Aligned the OHPM package name and install/import examples to the main package `bluetooth_kit`.

## 1.0.1

- Added BLE GATT and Classic SPP transport adapter classes.
- Added Harmony Bluetooth scanner, transport factory and permission helper.
- Improved README install guidance, real-device integration notes and demo placement.
- Updated demo GIF asset for OHPM/GitHub presentation.

## 1.0.0

- Initial Bluetooth Kit protocol and transport adapter skeleton.
