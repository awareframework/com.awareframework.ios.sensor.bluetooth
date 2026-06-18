import Foundation
import GRDB
import com_awareframework_ios_core

public struct BluetoothData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var address: String = ""
    public var jsonVersion: Int = 1
    public var label: String = ""
    public var name: String = ""
    public var os: String = "iOS"
    public var rssi: Int = 0
    public var scanLabel: Int64 = 0
    public var timezone: Int = AwareUtils.getTimeZone()

    public static let databaseTableName = "ios_bluetooth"

    public init() {}

    public init(
        timestamp: Int64, address: String, name: String, rssi: Int, scanLabel: Int64,
        label: String = ""
    ) {
        self.timestamp = timestamp
        self.address = address
        self.name = name
        self.rssi = rssi
        self.scanLabel = scanLabel
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        id = dict["id"] as? Int64
        timestamp = Self.int64(dict["timestamp"]) ?? 0
        deviceId =
            dict["deviceId"] as? String
            ?? dict["device_id"] as? String
            ?? AwareUtils.getCommonDeviceId()
        address = dict["address"] as? String ?? ""
        jsonVersion = Self.int(dict["jsonVersion"]) ?? 1
        label = dict["label"] as? String ?? ""
        name = dict["name"] as? String ?? ""
        os = dict["os"] as? String ?? "iOS"
        rssi = Self.int(dict["rssi"]) ?? 0
        scanLabel = Self.int64(dict["scanLabel"]) ?? 0
        timezone = Self.int(dict["timezone"]) ?? AwareUtils.getTimeZone()
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("deviceId", .text).notNull()
                t.column("address", .text).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("label", .text).notNull()
                t.column("name", .text).notNull()
                t.column("os", .text).notNull()
                t.column("rssi", .integer).notNull()
                t.column("scanLabel", .integer).notNull()
                t.column("timezone", .integer).notNull()
            }
        }
    }

    public func toDictionary() -> [String: Any] {
        [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "address": address,
            "jsonVersion": jsonVersion,
            "label": label,
            "name": name,
            "os": os,
            "rssi": rssi,
            "scanLabel": scanLabel,
            "timezone": timezone,
        ]
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? String { return Int64(value) }
        return nil
    }
}
