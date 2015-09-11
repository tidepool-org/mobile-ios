//
//  InsulinInputs.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/10/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

/*
    This part of the data model should provide:

    - A local cache of read-only data from the Tidepool service that contains time-stamped insulin inputs: either a baseline level of input, an extra bolus event, or a suspended indication.
    - It should return an array of inputs, given a start and end time. Since this may need to be fetched from the service, this probably needs a cancellable call back.
    - These should remain in sync with the service, but probably just cache a subset needed for display.
*/
