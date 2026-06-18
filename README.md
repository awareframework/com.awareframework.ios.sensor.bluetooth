# AWARE Bluetooth Sensor

The Bluetooth sensor scans nearby Bluetooth Low Energy (BLE) advertisements on iOS and stores discovered peripherals with RSSI values. It follows the AWARE iOS sensor package style and writes to the same table layout as the previous Bluetooth library format:

- `ios_bluetooth`
- `ios_bluetooth_device`

The sensor uses CoreBluetooth. iOS public APIs do not expose Bluetooth MAC addresses and do not allow general Classic Bluetooth discovery, so the `address` field stores CoreBluetooth's `CBPeripheral.identifier.uuidString`.

The scan scheduler follows the Android AWARE Bluetooth sensor design: a scan runs for a short window and then sleeps until the next configured interval. The default interval is 60 seconds with a 3 second BLE scan window.

## Installation

Add the package to your app target:

```text
https://github.com/awareframework/com.awareframework.ios.sensor.bluetooth.git
```

Then import the module:

```swift
import com_awareframework_ios_sensor_bluetooth
```

## Usage

```swift
let sensor = BluetoothSensor(BluetoothSensor.Config().apply { config in
    config.dbPath = "aware_bluetooth"
    config.scanIntervalSeconds = 60
    config.scanDurationSeconds = 3
})

sensor.start()
```

To stop collection:

```swift
sensor.stop()
```

## Permissions

Add Bluetooth usage text to the app `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app scans nearby Bluetooth Low Energy devices for AWARE sensing.</string>
```

For background BLE scanning, add the central background mode:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

## Configuration

`BluetoothSensor.Config` extends the common AWARE `SensorConfig`.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `scanIntervalSeconds` | `Double` | `60.0` | Seconds between scan starts. Set `0` for continuous scanning. |
| `scanDurationSeconds` | `Double` | `3.0` | Seconds to keep each BLE scan window open. The default mirrors Android AWARE's BLE scan window. |
| `allowDuplicates` | `Bool` | `false` | Whether CoreBluetooth should report and store duplicate advertisements during a scan window. Android AWARE stores a peripheral once per BLE scan window. |
| `sensorObserver` | `BluetoothObserver?` | `nil` | Callback for live scan events and BLE detections. |
| `dbPath` | `String` | `aware_bluetooth` | SQLite database path stem. |
| `dbTableName` | `String?` | `ios_bluetooth` | Active database table name. |

## Duty Cycle

The sensor does not scan continuously. It uses this cycle:

1. Start a BLE scan.
2. Save `ios_bluetooth_device` with the scan start timestamp.
3. Store each discovered BLE peripheral in `ios_bluetooth` with the same `scanLabel`.
4. If `scanIntervalSeconds` is greater than `0`, stop after `scanDurationSeconds` seconds.
5. Sleep until the next scan start based on `scanIntervalSeconds`.

When `scanIntervalSeconds` is `0`, the sensor keeps scanning continuously until `stop()` is called.

For example, with the defaults, the sensor scans for 3 seconds once every 60 seconds. This is intentionally conservative and follows the Android sensor's recommendation that Bluetooth scanning should use a 60 second or higher interval.

## Data Model

Records are stored under `aware_bluetooth.sqlite`.

### `ios_bluetooth`

This table stores BLE advertisement detections.

| Field | Type | Description |
| --- | --- | --- |
| `id` | `INTEGER PRIMARY KEY` | Local SQLite row id. |
| `timestamp` | `INTEGER` | Unix timestamp in milliseconds when the advertisement was observed. |
| `deviceId` | `TEXT` | AWARE device identifier for the collecting phone. |
| `address` | `TEXT` | CoreBluetooth peripheral identifier. This is not a MAC address on iOS. |
| `jsonVersion` | `INTEGER` | Schema version, currently `1`. |
| `label` | `TEXT` | Optional AWARE label. |
| `name` | `TEXT` | Advertised local name or peripheral name when available. |
| `os` | `TEXT` | `iOS`. |
| `rssi` | `INTEGER` | Received Signal Strength Indicator in dBm. |
| `scanLabel` | `INTEGER` | Timestamp in milliseconds for the scan window that produced the row. |
| `timezone` | `INTEGER` | Device timezone offset from AWARE utilities. |

CSV header:

```csv
id,timestamp,deviceId,address,jsonVersion,label,name,os,rssi,scanLabel,timezone
```

### `ios_bluetooth_device`

This table stores metadata about the collecting device for each scan window.

| Field | Type | Description |
| --- | --- | --- |
| `id` | `INTEGER PRIMARY KEY` | Local SQLite row id. |
| `timestamp` | `INTEGER` | Unix timestamp in milliseconds for the scan window. |
| `deviceId` | `TEXT` | AWARE device identifier. |
| `address` | `TEXT` | Same value as `deviceId`, kept for compatibility with the previous schema. |
| `jsonVersion` | `INTEGER` | Schema version, currently `1`. |
| `label` | `TEXT` | Optional AWARE label. |
| `name` | `TEXT` | `UIDevice.current.name`. |
| `os` | `TEXT` | `iOS`. |
| `timezone` | `INTEGER` | Device timezone offset from AWARE utilities. |

CSV header:

```csv
id,timestamp,deviceId,address,jsonVersion,label,name,os,timezone
```

## Notifications

| Notification | Description |
| --- | --- |
| `actionAwareBluetoothStart` | Posted when the sensor starts. |
| `actionAwareBluetoothStop` | Posted when the sensor stops. |
| `actionAwareBluetoothSync` | Posted when sync starts. |
| `actionAwareBluetoothSyncCompletion` | Posted when sync completes. |
| `actionAwareBluetoothSetLabel` | Posted when the label changes. |
| `actionAwareBluetoothNewDeviceBLE` | Posted when a BLE peripheral advertisement is detected. |
| `actionAwareBluetoothScanStarted` | Posted when a scan window starts. |
| `actionAwareBluetoothScanEnded` | Posted when a scan window ends. |
| `actionAwareBluetoothBLEScanStarted` | Posted when a BLE scan window starts. |
| `actionAwareBluetoothBLEScanEnded` | Posted when a BLE scan window ends. |
| `actionAwareBluetoothDisabled` | Posted when Bluetooth is powered off, unsupported, or unauthorized. |

## Observer

```swift
final class Observer: BluetoothObserver {
    func onBluetoothDetected(data: BluetoothData) {}

    func onBluetoothBLEDetected(data: BluetoothData) {
        print(data.toDictionary())
    }

    func onScanStarted() {}
    func onScanEnded() {}
    func onBLEScanStarted() {}
    func onBLEScanEnded() {}
    func onBluetoothDisabled() {}
}

let config = BluetoothSensor.Config().apply { config in
    config.scanIntervalSeconds = 60
    config.scanDurationSeconds = 3
    config.sensorObserver = Observer()
}

let sensor = BluetoothSensor(config)
sensor.start()
```

## Background Behavior

With `UIBackgroundModes` set to `bluetooth-central`, iOS may continue or resume BLE central activity in the background, but scanning is still controlled by iOS power and privacy policies. Timer-based scan intervals are best effort while the app is suspended.

To support restoration after iOS terminates the app, add CoreBluetooth state preservation and restoration:

1. Create `CBCentralManager` with `CBCentralManagerOptionRestoreIdentifierKey`.
2. Recreate the Bluetooth sensor early during app launch.
3. Implement `centralManager(_:willRestoreState:)`.
4. Restore scan options, active peripherals, and sensor configuration from persistent storage.
5. Reapply delegates to restored peripherals if the app connects to peripherals.

The current sensor is scan-only and does not connect to peripherals. It stores BLE advertisements that CoreBluetooth delivers while the process is running or resumed.

## iOS Limitations

- Only Bluetooth Low Energy advertisements are discoverable through public APIs.
- Classic Bluetooth device discovery is not available.
- MAC addresses are not available. Use `address` only as an iOS-scoped peripheral identifier.
- Peripheral identifiers may change after system resets, device restores, or privacy-related changes.
- Background scanning may receive fewer discoveries than foreground scanning.
