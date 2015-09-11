//
//  APIConnect.swift
//  Nutshell
//
//  Created by Ethan Look on 7/16/15.
//  Copyright (c) 2015 Tidepool. All rights reserved.
//

import Foundation
import UIKit

/*
    Most of the service interface is exposed via the data classes. However, for login/logout, some set of service interface functions are needed. Much of the needed login code should be portable from Urchin.
*/

class APIConnector {
    
    func login(username: String, password: String) {
    }
    
    func logout() {
    }

    /** 
        :returns: Returns true if connected.
        Uses reachability to determine whether device is connected to a network.
    */
    func isConnectedToNetwork() -> Bool {
        return true;
    }
    
 }