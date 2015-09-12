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

/*
    This part of the data model should provide:

    - A local cache of read-only data from the Tidepool service that contains time-stamped insulin inputs: either a baseline level of input, an extra bolus event, or a suspended indication.
    - It should return an array of inputs, given a start and end time. Since this may need to be fetched from the service, this probably needs a cancellable call back.
    - These should remain in sync with the service, but probably just cache a subset needed for display.
*/
