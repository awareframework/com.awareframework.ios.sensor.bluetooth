import Foundation
import UIKit
import com_awareframework_ios_core
import GRDB

public struct BluetoothDeviceData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var address: String = AwareUtils.getCommonDeviceId()
    public var jsonVersion: Int = 1
    public var label: String = ""
    public var name: String = UIDevice.current.name
    public var os: String = "iOS"
    public var timezone: Int = AwareUtils.getTimeZone()

    public static let databaseTableName = "ios_bluetooth_device"

    public init() {}

    public init(timestamp: Int64, label: String = "") {
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: Dictionary<String, Any>) {
        id = dict["id"] as? Int64
        timestamp = Self.int64(dict["timestamp"]) ?? 0
        deviceId = dict["deviceId"] as? String
            ?? dict["device_id"] as? String
            ?? AwareUtils.getCommonDeviceId()
        address = dict["address"] as? String ?? deviceId
        jsonVersion = Self.int(dict["jsonVersion"]) ?? 1
        label = dict["label"] as? String ?? ""
        name = dict["name"] as? String ?? UIDevice.current.name
        os = dict["os"] as? String ?? "iOS"
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
                t.column("timezone", .integer).notNull()
            }
        }
    }

    public func toDictionary() -> Dictionary<String, Any> {
        [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "address": address,
            "jsonVersion": jsonVersion,
            "label": label,
            "name": name,
            "os": os,
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
