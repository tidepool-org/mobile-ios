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

    - A current list of workout events from other local applications fetched via Healthkit. Note that workout events consist of single workout items or instances (as opposed to nut events which can have multiple instances).
    - This should synchronize with Healthkit occasionally, probably just upon application reactivation (since the user will have used some other app for the workout).
    - I don't think it is possible for this app to delete a workout event. 
    - AFAIK, none of these events would be sent to the Tidepool service. If they are synced with other devices, that would happen because the applications generating these events are doing that.
    - Some higher level function will be needed to return a sorted and searched list of NutEvent and WorkoutEvent items, which is what we actually need to display.
*/
