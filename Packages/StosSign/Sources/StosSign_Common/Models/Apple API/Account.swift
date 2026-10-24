//
//  Account.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

import Foundation

public class Account: Codable {
    public let appleID: String
    public let identifier: Int
    public let firstName: String
    public let lastName: String
    private var fallbackFirstName: String = ""
    private var fallbackLastName: String = ""
    var name: String {
        return firstName + " " + lastName
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appleID = try container.decode(String.self, forKey: .appleID)
        identifier = try container.decode(Int.self, forKey: .identifier)
        
        if let dsFirstName = try container.decodeIfPresent(String.self, forKey: .firstName) {
            firstName = dsFirstName
        } else if let fallbackFirstName = try container.decodeIfPresent(String.self, forKey: .fallbackFirstName) {
            firstName = fallbackFirstName
        } else {
            firstName = "Unknown"
        }

        if let dsLastName = try container.decodeIfPresent(String.self, forKey: .lastName) {
            lastName = dsLastName
        } else if let fallbackLastName = try container.decodeIfPresent(String.self, forKey: .fallbackLastName) {
            lastName = fallbackLastName
        } else {
            lastName = "Unknown"
        }
    }

    enum CodingKeys: String, CodingKey {
        case appleID = "email"
        case identifier = "personId"
        case firstName = "dsFirstName"
        case lastName = "dsLastName"
        case fallbackFirstName = "firstName"
        case fallbackLastName = "lastName"
    }
}
