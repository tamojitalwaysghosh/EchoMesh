# EchoMesh

EchoMesh is a Flutter-based offline peer-to-peer messaging app built on Bluetooth Low Energy (BLE). It lets users discover nearby devices, establish a direct connection, and exchange chat messages without requiring mobile data or an internet connection.

## App Overview

EchoMesh uses BLE to form a mesh-style communication link between devices. Each device can act as a host and as a client at the same time:

- **Discovery**: Scan for nearby EchoMesh peers advertising the EchoMesh BLE service.
- **Connection**: Establish a GATT connection with another nearby peer.
- **Messaging**: Send and receive messages through BLE characteristics.
- **Offline chat**: Exchange messages directly without relying on cellular or Wi-Fi.

## Key Features

- **Bluetooth scanning** for nearby EchoMesh devices
- **Automatic permission handling** for Android BLE requirements
- **Peer discovery** using EchoMesh-specific BLE advertisement keywords
- **Reliable connection management** with reconnection support
- **Bidirectional messaging** between connected devices
- **Background hosting** support for incoming BLE payloads
- **Local message storage** using Hive

## How EchoMesh Works

### 1. Permissions and Bluetooth state

The app ensures the user has granted required BLE permissions before starting scan or hosting. On Android the app requests:

- `bluetoothScan`
- `bluetoothConnect`
- `bluetoothAdvertise`
- `locationWhenInUse`

The app also checks the Bluetooth adapter state and notifies the user if Bluetooth is disabled.

### 2. Device discovery

EchoMesh scans for BLE devices advertising keywords such as `EM-` or `EchoMesh`. Discovered devices are presented in a nearby device list along with RSSI signal strength.

### 3. Connecting to a peer

When a user selects a nearby device, EchoMesh connects over BLE and discovers the EchoMesh service UUID. Once the required read/write characteristics are found, the app enables notifications and starts exchanging payloads.

### 4. Message transport

Messages are encoded as JSON-like payloads and transmitted over BLE characteristics. Each payload includes:

- sender ID
- sender handle
- message text
- timestamp
- emergency flag

Incoming payloads are decoded and stored in the local chat repository.

### 5. Hosting mode

EchoMesh can run a BLE host to accept incoming connections from other devices. This allows the app to receive messages even when acting as a peer in the network.

## Screens and Flow

- **Splash / startup** — initializes local storage and BLE services
- **Nearby devices** — scans for and shows nearby peers
- **Connect** — establishes BLE connection and opens a chat thread
- **Chat** — send and receive messages with a connected peer

## Project Structure

- `lib/main.dart` — app entry point and initialization
- `lib/app.dart` — router and app scaffold
- `lib/features/nearby/nearby_devices_screen.dart` — device discovery UI
- `lib/services/echomesh_ble_notifier.dart` — BLE scanning, connection, hosting, and messaging logic
- `lib/services/permissions_service.dart` — BLE permission handling
- `lib/repositories/` — chat, profile, and preference storage
- `lib/models/` — domain models such as wire payloads and chat messages
- `lib/shared/widgets/` — reusable UI components

## Installation

1. Clone the repository
2. Open in Flutter-enabled IDE or run from terminal
3. Run `flutter pub get`
4. Run the app on a physical Android device

> Note: BLE features require a physical Android device with Bluetooth support. Desktop and emulators do not reliably support BLE scanning and advertising.

## Build and Run

```bash
flutter pub get
flutter run
```

If you need to build a release APK:

```bash
flutter build apk --release
```

## Troubleshooting

- If scanning fails, make sure Bluetooth is enabled on your device.
- Grant all requested BLE permissions when prompted.
- If the app shows `Bluetooth must be turned on`, open device Bluetooth settings and enable Bluetooth.
- For Android 12+ ensure runtime permissions for Bluetooth Scan, Connect, and Advertise are accepted.

## Future Improvements

- Add multi-peer mesh routing for group messaging
- Support offline message relay through intermediate peers
- Add message encryption and authentication
- Add richer UI for chat threads and peer profiles

## License

This project is provided as-is for demonstration and development purposes.