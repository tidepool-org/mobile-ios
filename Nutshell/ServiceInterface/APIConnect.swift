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

/*
    Most of the service interface is exposed via the data classes. However, for login/logout, some set of service interface functions are needed. Much of the needed login code should be portable from Urchin.
*/

class APIConnector {
    
    class func login(username: String, password: String, completion: (Bool) -> (Void)) {
        
        // For now, just return true after a second... 
        // TODO: actual login attempt...
        NutUtils.dispatchBoolToVoidAfterSecs(0.5, result:true, boolToVoid:completion)
        
    }
    
    class func logout() {
    }

    /** 
        :returns: Returns true if connected.
        Uses reachability to determine whether device is connected to a network.
    */
    class func isConnectedToNetwork() -> Bool {
        return true;
    }
    
 }