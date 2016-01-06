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

import UIKit

/// Provides an ordered array of GraphDataLayer objects.
class TidepoolGraphLayout: GraphLayout {
    
    //
    // MARK: - Overrides for graph customization
    //

    // create and return an array of GraphDataLayer objects, w/o data, ordered in view layer from back to front (i.e., last item in array will be drawn last)
    override func graphLayers(viewSize: CGSize, timeIntervalForView: NSTimeInterval, startTime: NSDate) -> [GraphDataLayer] {

        let workoutLayer = WorkoutGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, dataType: WorkoutGraphDataType(), layout: self)
        
        let mealLayer = MealGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, dataType: MealGraphDataType(), layout: self)
        
        let cbgLayer = CbgGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, dataType: CbgGraphDataType(), layout: self)
        
        let smbgLayer = SmbgGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, dataType: SmbgGraphDataType(), layout: self)

        let basalLayer = BasalGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, dataType: BasalGraphDataType(), layout: self)

        let bolusLayer = BolusGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, dataType: BolusGraphDataType(), layout: self)

        let wizardLayer = WizardGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, dataType: WizardGraphDataType(), layout: self)

        // Note: ordering is important! E.g., wizard layer draws after bolus layer so it can place circles above related bolus rectangles.
        return [workoutLayer, mealLayer, cbgLayer, smbgLayer, basalLayer, bolusLayer, wizardLayer]
    }
    
    //
    // MARK: - Configuration vars
    //

    //
    // Blood glucose data (cbg and smbg)
    //
    // NOTE: only supports minvalue==0 right now!
    let kGlucoseMinValue: CGFloat = 0.0
    let kGlucoseMaxValue: CGFloat = 340.0
    let kGlucoseRange: CGFloat = 340.0
    let kGlucoseConversionToMgDl: CGFloat = 18.0
    let highBoundary: NSNumber = 180.0
    let lowBoundary: NSNumber = 80.0
    // Colors
    let highColor = Styles.purpleColor
    let targetColor = Styles.greenColor
    let lowColor = Styles.peachColor

    // Keep track of rects drawn for later drawing. E.g., Wizard circles are drawn just over associated Bolus labels.
    var bolusRects: [CGRect] = []
    
    // Glucose readings go from 340(?) down to 0 in a section just below the header
    var yTopOfGlucose: CGFloat = 0.0
    var yBottomOfGlucose: CGFloat = 0.0
    var yPixelsGlucose: CGFloat = 0.0
    // Wizard readings overlap the bottom part of the glucose readings
    var yBottomOfWizard: CGFloat = 0.0
    // Bolus and Basal readings go in a section below glucose
    var yTopOfBolus: CGFloat = 0.0
    var yBottomOfBolus: CGFloat = 0.0
    var yPixelsBolus: CGFloat = 0.0
    var yTopOfBasal: CGFloat = 0.0
    var yBottomOfBasal: CGFloat = 0.0
    var yPixelsBasal: CGFloat = 0.0
    // Workout durations go in a section below Basal
    var yTopOfWorkout: CGFloat = 0.0
    var yBottomOfWorkout: CGFloat = 0.0
    var yPixelsWorkout: CGFloat = 0.0

    //
    // MARK: - Private constants
    //
    
    private let kGraphWizardHeight: CGFloat = 27.0
    // After removing a constant height for the header and wizard values, the remaining graph vertical space is divided into four sections based on the following fractions (which should add to 1.0)
    private let kGraphFractionForGlucose: CGFloat = 180.0/266.0
    private let kGraphFractionForBolusAndBasal: CGFloat = 76.0/266.0
    // Each section has some base offset as well
    private let kGraphGlucoseBaseOffset: CGFloat = 2.0
    private let kGraphWizardBaseOffset: CGFloat = 2.0
    private let kGraphBolusBaseOffset: CGFloat = 2.0
    private let kGraphBasalBaseOffset: CGFloat = 2.0
    private let kGraphWorkoutBaseOffset: CGFloat = 2.0

    //
    // MARK: - Configuration
    //

    /// Dynamic layout configuration based on view sizing
    override func configure(viewSize: CGSize) {
        
        super.configure(viewSize)

        self.headerHeight = 32.0
        self.yAxisLineLeftMargin = 26.0
        self.yAxisLineRightMargin = 10.0
        self.yAxisLineColor = UIColor.whiteColor()
        self.backgroundColor = Styles.veryLightGreyColor
        self.yAxisValuesWithLines = [80, 180]
        self.yAxisValuesWithLabels = [40, 80, 180, 300]
    
        self.axesLabelTextColor = UIColor(hex: 0x58595B)
        self.axesLabelTextFont = Styles.smallRegularFont
        
        // Tweak: if height is less than 320 pixels, let the wizard circles drift up into the low area of the blood glucose data since that should be clear
        let wizardHeight = viewSize.height < 320.0 ? 0.0 : kGraphWizardHeight

        // The pie to divide is what's left over after removing constant height areas
        let graphHeight = viewSize.height - headerHeight - wizardHeight
        
        // Put the workout data at the top, over the X-axis
        yTopOfWorkout = 2.0
        yBottomOfWorkout = viewSize.height
        yPixelsWorkout = headerHeight - 4.0
        
        // The largest section is for the glucose readings just below the header
        self.yTopOfGlucose = headerHeight
        self.yBottomOfGlucose = self.yTopOfGlucose + floor(kGraphFractionForGlucose * graphHeight) - kGraphGlucoseBaseOffset
        self.yPixelsGlucose = self.yBottomOfGlucose - self.yTopOfGlucose
        
        // Wizard data sits above the bolus readings, in a fixed space area, possibly overlapping the bottom of the glucose graph which should be empty of readings that low.
        // TODO: put wizard data on top of corresponding bolus data!
        self.yBottomOfWizard = self.yBottomOfGlucose + wizardHeight
        
        // At the bottom are the bolus and basal readings
        self.yTopOfBolus = self.yBottomOfWizard + kGraphWizardBaseOffset
        self.yBottomOfBolus = viewSize.height
        self.yPixelsBolus = self.yBottomOfBolus - self.yTopOfBolus
        
        // Basal values sit just below the bolus readings
        self.yBottomOfBasal = self.yBottomOfBolus
        self.yPixelsBasal = ceil(self.yPixelsBolus/2)
        self.yTopOfBasal = self.yTopOfBolus - self.yPixelsBasal

        // Y-axis tracks the glucose readings
        self.yAxisRange = kGlucoseRange
        self.yAxisBase = yBottomOfGlucose
        self.yAxisPixels = yPixelsGlucose
    }
    
    //
    // MARK: - Tidepool specific utility functions
    //
    
    func bolusRectAtPosition(rect: CGRect) -> CGRect {
        var result = CGRectZero
        let rectLeft = rect.origin.x
        let rectRight = rectLeft + rect.width
        for bolusRect in bolusRects {
            let bolusLeftX = bolusRect.origin.x
            let bolusRightX = bolusLeftX + bolusRect.width
            if bolusRightX > rectLeft && bolusLeftX < rectRight {
                if bolusRect.height > result.height {
                    // return the bolusRect that is largest and intersects the x position of the target rect
                    result = bolusRect
                }
            }
        }
        return result
    }
    

}
