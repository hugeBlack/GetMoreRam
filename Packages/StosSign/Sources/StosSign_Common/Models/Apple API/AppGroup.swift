//
//  AppGroup.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

import Foundation

public struct AppGroup: Codable {
    public var name: String
    public var identifier: String
    public var groupIdentifier: String
    
    public init(name: String, identifier: String, groupIdentifier: String) {
        self.name = name
        self.identifier = identifier
        self.groupIdentifier = groupIdentifier
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case identifier = "applicationGroup"
        case groupIdentifier = "identifier"
    }
}
