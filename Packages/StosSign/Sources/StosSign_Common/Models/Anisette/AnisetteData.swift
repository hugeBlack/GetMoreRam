//
//  AnisetteData.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

import Foundation

public class AnisetteData: Codable {
    public let machineID: String
    public let oneTimePassword: String
    public let localUserID: String
    public let routingInfo: UInt64
    public let deviceUniqueIdentifier: String
    public let deviceSerialNumber: String
    public let deviceDescription: String
    public let date: Date
    public let locale: Locale
    public let timeZone: TimeZone
    
    public init(machineID: String,
         oneTimePassword: String,
         localUserID: String,
         routingInfo: UInt64,
         deviceUniqueIdentifier: String,
         deviceSerialNumber: String,
         deviceDescription: String,
         date: Date,
         locale: Locale,
         timeZone: TimeZone) {
        self.machineID = machineID
        self.oneTimePassword = oneTimePassword
        self.localUserID = localUserID
        self.routingInfo = routingInfo
        self.deviceUniqueIdentifier = deviceUniqueIdentifier
        self.deviceSerialNumber = deviceSerialNumber
        self.deviceDescription = deviceDescription
        self.date = date
        self.locale = locale
        self.timeZone = timeZone
    }
    
    enum CodingKeys: String, CodingKey {
        case machineID, oneTimePassword, localUserID, routingInfo, deviceUniqueIdentifier, deviceSerialNumber, deviceDescription, date, locale, timeZone
    }

    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.machineID = try container.decode(String.self, forKey: .machineID)
        self.oneTimePassword = try container.decode(String.self, forKey: .oneTimePassword)
        self.localUserID = try container.decode(String.self, forKey: .localUserID)
        
        let routingInfoString = try container.decode(String.self, forKey: .routingInfo)
        guard let routingInfo = UInt64(routingInfoString) else {
            throw DecodingError.dataCorruptedError(forKey: .routingInfo, in: container, debugDescription: "Invalid routingInfo value")
        }
        self.routingInfo = routingInfo
        
        self.deviceUniqueIdentifier = try container.decode(String.self, forKey: .deviceUniqueIdentifier)
        self.deviceSerialNumber = try container.decode(String.self, forKey: .deviceSerialNumber)
        self.deviceDescription = try container.decode(String.self, forKey: .deviceDescription)
        

        let dateString = try container.decode(String.self, forKey: .date)
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Invalid date string")
        }
        self.date = date
        

        let localeIdentifier = try container.decode(String.self, forKey: .locale)
        self.locale = Locale(identifier: localeIdentifier)
        
        let timeZoneIdentifier = try container.decode(String.self, forKey: .timeZone)
        self.timeZone = TimeZone(abbreviation: timeZoneIdentifier) ?? TimeZone.current
    }
}
