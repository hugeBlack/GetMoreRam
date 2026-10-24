//
//  AppleAPI+Legacy.swift
//  StosSign
//
//  Created by Stossy11 on 06/12/2025.
//

import Foundation
import StosSign_Common

@available(*, deprecated, message: "Please Use async functions instead")
extension AppleAPI {
    public func fetchTeamsForAccount(account: Account, session: AppleAPISession, completion: @escaping ([Team]?, Error?) -> Void) {
        Task {
            do {
                let teams = try await fetchTeamsForAccount(account: account, session: session)
                completion(teams, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    public func fetchDevicesForTeam(team: Team, session: AppleAPISession, types: DeviceType, completion: @escaping ([Device]?, Error?) -> Void) {
        Task {
            do {
                let devices = try await fetchDevicesForTeam(team: team, session: session, types: types)
                completion(devices, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    public func registerDeviceWithName(name: String, identifier: String, type: DeviceType, team: Team, session: AppleAPISession, completion: @escaping (Device?, Error?) -> Void) {
        Task {
            do {
                let device = try await registerDeviceWithName(name: name, identifier: identifier, type: type, team: team, session: session)
                completion(device, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    public func fetchAppIDsForTeam(team: Team, session: AppleAPISession, completionHandler: @escaping ([AppID]?, Error?) -> Void) {
        Task {
            do {
                let appIDs = try await fetchAppIDsForTeam(team: team, session: session)
                completionHandler(appIDs, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
    
    public func addAppID(name: String, bundleIdentifier: String, team: Team, session: AppleAPISession, completionHandler: @escaping (AppID?, Error?) -> Void) {
        Task {
            do {
                let appID = try await addAppID(name: name, bundleIdentifier: bundleIdentifier, team: team, session: session)
                completionHandler(appID, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
    
    public func updateAppID(_ appID: AppID, team: Team, session: AppleAPISession, completionHandler: @escaping (AppID?, Error?) -> Void) {
        Task {
            do {
                let updatedAppID = try await qHupdateAppID(appID, team: team, session: session)
                completionHandler(updatedAppID, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
    
    public func deleteAppID(_ appID: AppID, team: Team, session: AppleAPISession, completionHandler: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let success = try await deleteAppID(appID, team: team, session: session)
                completionHandler(success, nil)
            } catch {
                completionHandler(false, error)
            }
        }
    }
    
    public func fetchAppGroupsForTeam(team: Team, session: AppleAPISession, completionHandler: @escaping ([AppGroup]?, Error?) -> Void) {
        Task {
            do {
                let groups = try await fetchAppGroupsForTeam(team: team, session: session)
                completionHandler(groups, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
    
    public func addAppGroup(name: String, groupIdentifier: String, team: Team, session: AppleAPISession, completionHandler: @escaping (AppGroup?, Error?) -> Void) {
        Task {
            do {
                let group = try await addAppGroup(name: name, groupIdentifier: groupIdentifier, team: team, session: session)
                completionHandler(group, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
    
    public func assignAppID(_ appID: AppID, toGroups groups: [AppGroup], team: Team, session: AppleAPISession, completionHandler: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let success = try await assignAppID(appID, toGroups: groups, team: team, session: session)
                completionHandler(success, nil)
            } catch {
                completionHandler(false, error)
            }
        }
    }
    
    public func fetchProvisioningProfileForAppID(appID: AppID, deviceType: DeviceType, team: Team, session: AppleAPISession, completionHandler: @escaping (ProvisioningProfile?, Error?) -> Void) {
        Task {
            do {
                let profile = try await fetchProvisioningProfileForAppID(appID: appID, deviceType: deviceType, team: team, session: session)
                completionHandler(profile, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
    
    public func deleteProvisioningProfile(_ provisioningProfile: ProvisioningProfile, team: Team, session: AppleAPISession, completionHandler: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                let success = try await deleteProvisioningProfile(provisioningProfile, team: team, session: session)
                completionHandler(success, nil)
            } catch {
                completionHandler(false, error)
            }
        }
    }
    
    public func fetchAccount(session: AppleAPISession, completionHandler: @escaping (Account?, Error?) -> Void) {
        Task {
            do {
                let success = try await fetchAccount(session: session)
                completionHandler(success, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
}

