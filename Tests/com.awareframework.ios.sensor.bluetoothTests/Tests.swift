import Testing
@testable import com_awareframework_ios_sensor_bluetooth

@Test func bluetoothConfigScanIntervalUsesSeconds() async throws {
    let config = BluetoothSensor.Config()
    #expect(config.scanIntervalSeconds == 60)
    #expect(config.isContinuousScanMode == false)

    config.set(config: ["scanIntervalSeconds": 30.0])
    #expect(config.scanIntervalSeconds == 30)
    #expect(config.isContinuousScanMode == false)

    config.set(config: ["scanIntervalSeconds": 0.0])
    #expect(config.scanIntervalSeconds == 0)
    #expect(config.isContinuousScanMode == true)

    config.set(config: ["scanIntervalSeconds": 15])
    #expect(config.scanIntervalSeconds == 15)
    #expect(config.isContinuousScanMode == false)
}

@Test func bluetoothDataDictionaryUsesExpectedKeys() async throws {
    let data = BluetoothData(
        timestamp: 1,
        address: "PERIPHERAL-ID",
        name: "Device",
        rssi: -55,
        scanLabel: 1
    )

    let dict = data.toDictionary()
    #expect(dict["timestamp"] as? Int64 == 1)
    #expect(dict["address"] as? String == "PERIPHERAL-ID")
    #expect(dict["name"] as? String == "Device")
    #expect(dict["rssi"] as? Int == -55)
    #expect(dict["scanLabel"] as? Int64 == 1)
}
