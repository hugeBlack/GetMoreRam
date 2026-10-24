//
//  Team.swift
//  StosSign
//
//  Created by Stossy11 on 19/03/2025.
//

import Foundation

public enum TeamType: Int, Codable {
    case unknown
    case free
    case individual
    case organization
}


public struct Team {
    public var name: String
    public var identifier: String
    public var type: TeamType
    public var account: Account
    
    public init(name: String, identifier: String, type: TeamType, account: Account) {
        self.name = name
        self.identifier = identifier
        self.type = type
        self.account = account
    }
    
    public init?(account: Account, responseDictionary: [String: Any]) {
        guard let name = responseDictionary["name"] as? String,
              let identifier = responseDictionary["teamId"] as? String,
              let teamType = responseDictionary["type"] as? String else {
            return nil
        }
        
        var type = TeamType.unknown
        
        if teamType == "Company/Organization" {
            type = .organization
        } else if teamType == "Individual" {
            if let memberships = responseDictionary["memberships"] as? [[String: Any]],
               let membership = memberships.first,
               let name = membership["name"] as? String,
               memberships.count == 1 && name.lowercased().contains("free") {
                type = .free
            } else {
                type = .individual
            }
        } else {
            type = .unknown
        }
        
        self.init(name: name, identifier: identifier, type: type, account: account)
    }
}
