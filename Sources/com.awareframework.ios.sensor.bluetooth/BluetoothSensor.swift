import Foundation
import CoreBluetooth
import com_awareframework_ios_core

extension Notification.Name {
    public static let actionAwareBluetoothStart = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_START)
    public static let actionAwareBluetoothStop = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_STOP)
    public static let actionAwareBluetoothSync = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_SYNC)
    public static let actionAwareBluetoothSyncCompletion = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_SYNC_COMPLETION)
    public static let actionAwareBluetoothSetLabel = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_SET_LABEL)

    public static let actionAwareBluetoothNewDevice = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_NEW_DEVICE)
    public static let actionAwareBluetoothNewDeviceBLE = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_NEW_DEVICE_BLE)
    public static let actionAwareBluetoothScanStarted = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_SCAN_STARTED)
    public static let actionAwareBluetoothScanEnded = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_SCAN_ENDED)
    public static let actionAwareBluetoothBLEScanStarted = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_BLE_SCAN_STARTED)
    public static let actionAwareBluetoothBLEScanEnded = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_BLE_SCAN_ENDED)
    public static let actionAwareBluetoothDisabled = Notification.Name(BluetoothSensor.ACTION_AWARE_BLUETOOTH_DISABLED)
}

public protocol BluetoothObserver {
    func onBluetoothDetected(data: BluetoothData)
    func onBluetoothBLEDetected(data: BluetoothData)
    func onScanStarted()
    func onScanEnded()
    func onBLEScanStarted()
    func onBLEScanEnded()
    func onBluetoothDisabled()
}

public class BluetoothSensor: AwareSensor {
    public static let TAG = "Aware::Bluetooth"

    public static let ACTION_AWARE_BLUETOOTH_START = "com.aware.sensor.bluetooth.SENSOR_START"
    public static let ACTION_AWARE_BLUETOOTH_STOP = "com.aware.sensor.bluetooth.SENSOR_STOP"
    public static let ACTION_AWARE_BLUETOOTH_SYNC = "com.aware.sensor.bluetooth.SYNC"
    public static let ACTION_AWARE_BLUETOOTH_SYNC_COMPLETION = "com.awareframework.ios.sensor.bluetooth.SENSOR_SYNC_COMPLETION"
    public static let ACTION_AWARE_BLUETOOTH_SET_LABEL = "com.aware.sensor.bluetooth.SET_LABEL"

    public static let ACTION_AWARE_BLUETOOTH_NEW_DEVICE = "ACTION_AWARE_BLUETOOTH_NEW_DEVICE"
    public static let ACTION_AWARE_BLUETOOTH_NEW_DEVICE_BLE = "ACTION_AWARE_BLUETOOTH_NEW_DEVICE_BLE"
    public static let ACTION_AWARE_BLUETOOTH_SCAN_STARTED = "ACTION_AWARE_BLUETOOTH_SCAN_STARTED"
    public static let ACTION_AWARE_BLUETOOTH_SCAN_ENDED = "ACTION_AWARE_BLUETOOTH_SCAN_ENDED"
    public static let ACTION_AWARE_BLUETOOTH_BLE_SCAN_STARTED = "ACTION_AWARE_BLUETOOTH_BLE_SCAN_STARTED"
    public static let ACTION_AWARE_BLUETOOTH_BLE_SCAN_ENDED = "ACTION_AWARE_BLUETOOTH_BLE_SCAN_ENDED"
    public static let ACTION_AWARE_BLUETOOTH_DISABLED = "ACTION_AWARE_BLUETOOTH_DISABLED"

    public static let EXTRA_LABEL = "label"
    public static let EXTRA_DATA = "data"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"
    public static let EXTRA_OBJECT_TYPE = "objectType"
    public static let EXTRA_TABLE_NAME = "tableName"

    public var CONFIG = Config()

    private let centralQueue = DispatchQueue(label: "com.awareframework.ios.sensor.bluetooth.central", qos: .utility)
    private var centralManager: CBCentralManager?
    private var isRunning = false
    private var isScanning = false
    private var scanLabel: Int64 = 0
    private var scanStopTimer: DispatchSourceTimer?
    private var nextScanTimer: DispatchSourceTimer?
    private var discoveredPeripheralIDs = Set<String>()

    public class Config: SensorConfig {
        public var sensorObserver: BluetoothObserver?
        public var scanIntervalSeconds = 60.0
        public var scanDurationSeconds = 3.0
        public var allowDuplicates = false

        var isContinuousScanMode: Bool {
            scanIntervalSeconds == 0
        }

        public override init() {
            super.init()
            self.dbPath = "aware_bluetooth"
            self.dbTableName = BluetoothData.databaseTableName
        }

        public func apply(closure: (_ config: BluetoothSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }

        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
            if let scanIntervalSeconds = config["scanIntervalSeconds"] as? Double {
                self.scanIntervalSeconds = scanIntervalSeconds
            } else if let scanIntervalSeconds = config["scanIntervalSeconds"] as? Int {
                self.scanIntervalSeconds = Double(scanIntervalSeconds)
            }
            if let scanDurationSeconds = config["scanDurationSeconds"] as? Double {
                self.scanDurationSeconds = scanDurationSeconds
            }
            if let allowDuplicates = config["allowDuplicates"] as? Bool {
                self.allowDuplicates = allowDuplicates
            }
        }
    }

    public override convenience init() {
        self.init(BluetoothSensor.Config())
    }

    public init(_ config: BluetoothSensor.Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        super.syncConfig = DbSyncConfig().apply { setting in
            setting.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.bluetooth.sync.queue")
        }

        if let sqliteEngine = dbEngine as? SQLiteEngine,
           let queue = sqliteEngine.getSQLiteInstance() {
            do {
                try BluetoothData.createTable(queue: queue)
                try BluetoothDeviceData.createTable(queue: queue)
            } catch {
                if CONFIG.debug {
                    print(Self.TAG, error)
                }
            }
        }
    }

    public override func start() {
        centralQueue.async { [weak self] in
            guard let self, self.isRunning == false else { return }
            self.isRunning = true
            self.ensureCentralManager()
            self.notificationCenter.post(name: .actionAwareBluetoothStart, object: self)
            self.startScanIfPossible()
        }
    }

    public override func stop() {
        centralQueue.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.cancelTimers()
            self.stopCurrentScan()
            self.notificationCenter.post(name: .actionAwareBluetoothStop, object: self)
        }
    }

    public override func sync(force: Bool = false) {
        guard let engine = dbEngine, let syncConfig = syncConfig else { return }
        syncConfig.debug = CONFIG.debug
        engine.startSync(syncConfig.apply { setting in
            setting.completionHandler = { status, error in
                var userInfo: Dictionary<String, Any> = [
                    Self.EXTRA_STATUS: status,
                    Self.EXTRA_TABLE_NAME: BluetoothDeviceData.databaseTableName,
                    Self.EXTRA_OBJECT_TYPE: BluetoothDeviceData.self,
                ]
                if let error { userInfo[Self.EXTRA_ERROR] = error }
                self.notificationCenter.post(name: .actionAwareBluetoothSyncCompletion, object: self, userInfo: userInfo)
            }
        })
        engine.startSync(syncConfig.apply { setting in
            setting.completionHandler = { status, error in
                var userInfo: Dictionary<String, Any> = [
                    Self.EXTRA_STATUS: status,
                    Self.EXTRA_TABLE_NAME: BluetoothData.databaseTableName,
                    Self.EXTRA_OBJECT_TYPE: BluetoothData.self,
                ]
                if let error { userInfo[Self.EXTRA_ERROR] = error }
                self.notificationCenter.post(name: .actionAwareBluetoothSyncCompletion, object: self, userInfo: userInfo)
            }
        })
        notificationCenter.post(name: .actionAwareBluetoothSync, object: self)
    }

    public override func set(label: String) {
        CONFIG.label = label
        notificationCenter.post(name: .actionAwareBluetoothSetLabel, object: self, userInfo: [Self.EXTRA_LABEL: label])
    }

    private func ensureCentralManager() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(
            delegate: self,
            queue: centralQueue,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
    }

    private func startScanIfPossible() {
        guard isRunning else { return }
        ensureCentralManager()
        guard let centralManager else { return }

        switch centralManager.state {
        case .poweredOn:
            startCurrentScan()
        case .poweredOff, .unauthorized, .unsupported:
            notifyBluetoothDisabled()
            scheduleNextScan(after: unavailableRetryDelay)
        case .unknown, .resetting:
            scheduleNextScan(after: 1)
        @unknown default:
            scheduleNextScan(after: unavailableRetryDelay)
        }
    }

    private func startCurrentScan() {
        guard isRunning, let centralManager, centralManager.state == .poweredOn else { return }
        cancelTimers()
        scanLabel = nowMilliseconds()
        discoveredPeripheralIDs.removeAll()
        saveDeviceData(timestamp: scanLabel)
        isScanning = true

        CONFIG.sensorObserver?.onScanStarted()
        CONFIG.sensorObserver?.onBLEScanStarted()
        notificationCenter.post(name: .actionAwareBluetoothScanStarted, object: self)
        notificationCenter.post(name: .actionAwareBluetoothBLEScanStarted, object: self)

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: CONFIG.allowDuplicates]
        )

        if isContinuousScanMode == false {
            scanStopTimer = makeTimer(after: scanDurationSeconds) { [weak self] in
                self?.stopCurrentScan()
                self?.scheduleNextScan(after: self?.rescanDelay ?? 0)
            }
        }
    }

    private func stopCurrentScan() {
        guard isScanning else { return }
        centralManager?.stopScan()
        isScanning = false
        scanStopTimer?.cancel()
        scanStopTimer = nil

        CONFIG.sensorObserver?.onScanEnded()
        CONFIG.sensorObserver?.onBLEScanEnded()
        notificationCenter.post(name: .actionAwareBluetoothScanEnded, object: self)
        notificationCenter.post(name: .actionAwareBluetoothBLEScanEnded, object: self)
        discoveredPeripheralIDs.removeAll()
    }

    private func scheduleNextScan(after delay: TimeInterval) {
        guard isRunning else { return }
        nextScanTimer?.cancel()
        nextScanTimer = makeTimer(after: max(0, delay)) { [weak self] in
            self?.startScanIfPossible()
        }
    }

    private func cancelTimers() {
        scanStopTimer?.cancel()
        scanStopTimer = nil
        nextScanTimer?.cancel()
        nextScanTimer = nil
    }

    private func makeTimer(after delay: TimeInterval, handler: @escaping () -> Void) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: centralQueue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler(handler: handler)
        timer.resume()
        return timer
    }

    var isContinuousScanMode: Bool {
        CONFIG.isContinuousScanMode
    }

    private var unavailableRetryDelay: TimeInterval {
        isContinuousScanMode ? 1 : scanInterval
    }

    private var scanInterval: TimeInterval {
        max(1, CONFIG.scanIntervalSeconds)
    }

    private var scanDurationSeconds: TimeInterval {
        min(max(1, CONFIG.scanDurationSeconds), scanInterval)
    }

    private var rescanDelay: TimeInterval {
        max(0, scanInterval - scanDurationSeconds)
    }

    private func saveDeviceData(timestamp: Int64) {
        let data = BluetoothDeviceData(timestamp: timestamp, label: CONFIG.label)
        dbEngine?.save([data])
    }

    private func notifyBluetoothDisabled() {
        CONFIG.sensorObserver?.onBluetoothDisabled()
        notificationCenter.post(name: .actionAwareBluetoothDisabled, object: self)
    }

    private func nowMilliseconds() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}

extension BluetoothSensor: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if CONFIG.debug {
            print(Self.TAG, "state:", central.state.rawValue)
        }
        guard isRunning else { return }
        startScanIfPossible()
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard isRunning else { return }
        let rssi = RSSI.intValue
        guard rssi != 127 else { return }

        let peripheralID = peripheral.identifier.uuidString
        if CONFIG.allowDuplicates == false {
            guard discoveredPeripheralIDs.contains(peripheralID) == false else { return }
            discoveredPeripheralIDs.insert(peripheralID)
        }

        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let data = BluetoothData(
            timestamp: nowMilliseconds(),
            address: peripheralID,
            name: advertisedName ?? peripheral.name ?? "",
            rssi: rssi,
            scanLabel: scanLabel == 0 ? nowMilliseconds() : scanLabel,
            label: CONFIG.label
        )

        dbEngine?.save([data])
        CONFIG.sensorObserver?.onBluetoothBLEDetected(data: data)
        notificationCenter.post(
            name: .actionAwareBluetoothNewDeviceBLE,
            object: self,
            userInfo: [Self.EXTRA_DATA: data.toDictionary()]
        )
    }
}
