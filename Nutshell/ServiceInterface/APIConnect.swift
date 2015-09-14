/*
* Copyright (c) 2015, Tidepool Project
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the associated License, which is identical to the BSD 2-Clause
* License as published by the Open Source Initiative at opensource.org.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the License for more details.
*
* You should have received a copy of the License along with this program; if
* not, you can obtain one from Tidepool Project at tidepool.org.
*/

import Foundation
import UIKit
import Alamofire

/*
    Most of the service interface is exposed via the data classes. However, for login/logout, some set of service interface functions are needed. Much of the needed login code should be portable from Urchin.
*/

class APIConnector {
    // MARK: - Constants
    
    static let kSessionTokenDefaultKey = "SToken"
    static let kSessionIdHeader = "x-tidepool-session-token"
    
    // Dictionary of servers and their base URLs
    static let kServers = ["Production" :   "https://api.tidepool.io",
                           "Staging" :      "https://staging-api.tidepool.io",
                           "Development" :  "https://devel-api.tidepool.io"]
    
    // Session token, acquired on login and saved in NSUserDefaults
    var _sessionToken: (String?)
    
    // Base URL for API calls, set during initialization
    var _baseUrl: (NSURL)
    
    // MARK: Initializaion
    
    // Required initializer
    required init(baseUrl: NSURL) {
        _baseUrl = baseUrl
    }
    
    
    // Convenience initializer using the server name
    convenience init(server: String = "Production") {
        self.init(baseUrl: NSURL(string:APIConnector.kServers[server]!)!)
    }
    
    /**
     * Logs in the user and obtains the session token for the session (stored internally)
     */
    func login(username: String,
        password: String,
        completion: (NSURLRequest?, NSURLResponse?, Result<AnyObject>) -> (Void)) {
            let endpoint = "auth/login"
            sendRequest(endpoint: endpoint) { (request, response, result) -> (Void) in
                if let httpResponse:(NSHTTPURLResponse) = response as? NSHTTPURLResponse {
                    // Look for the auth token
                    self._sessionToken = httpResponse.allHeaderFields[APIConnector.kSessionIdHeader] as! String?
                    print("Got session token: \(self._sessionToken)")
                } else {
                    // We did not get a session token
                    print("Did not find a session token!")
                }
                
                completion(request, response, result)
            }
    }
    
    func logout(completion: (NSError) -> (Void)) {
        
    }
    
    /**
    :returns: Returns true if connected.
    Uses reachability to determine whether device is connected to a network.
    */
    class func isConnectedToNetwork() -> Bool {
        return true;
    }
    
    func clearSessionToken() -> Void {
        NSUserDefaults.standardUserDefaults().removeObjectForKey(APIConnector.kSessionTokenDefaultKey);
        _sessionToken = nil;
    }

    // MARK: - Internal methods
    
    /**
     * Sends a request to the specified endpoint
    */
    func sendRequest(requestType: (Alamofire.Method)? = Method.GET,
        endpoint: (String),
        headers: [String: String]? = nil,
        completion: (NSURLRequest?, NSURLResponse?, Result<AnyObject>) -> (Void))
    {
        let url = _baseUrl.URLByAppendingPathComponent(endpoint)
        var apiHeaders = getApiHeaders()
        Alamofire.request(requestType!, url, headers: headers).responseJSON {
            (request, response, result) -> Void in
            completion(request, response, result)
        }
    }
    
    func getApiHeaders() -> [String: String]? {
        if ( _sessionToken != nil ) {
            return [kSessionIdHeader : _sessionToken]
        }
        return nil;
    }
 }