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
    
    var mainEventTime: Date
    var dataDetected = false
    var displayGridLines = true
    /// Notes to display.
    var notesToDisplay: [BlipNote] = []

    init (viewSize: CGSize, mainEventTime: Date, tzOffsetSecs: Int) {

        self.mainEventTime = mainEventTime
        let startPixelsPerHour = 80
        // TODO: figure number of tiles based on view size, in order to get 24 hours. 3 tiles gets about 28 hours on a portrait iPad (768/80 = 9.6 hours x 3 = 28.8 hours), where screen size is one tile wide - see tilesInView below.
        let numberOfTiles = 3
        let cellTI = TimeInterval(viewSize.width * 3600.0/CGFloat(startPixelsPerHour))
        let graphTI = cellTI * TimeInterval(numberOfTiles)
        let startTime = mainEventTime.addingTimeInterval(-graphTI/2.0)
        super.init(viewSize: viewSize, startTime: startTime, timeIntervalPerTile: cellTI, numberOfTiles: numberOfTiles, tilesInView: 1, tzOffsetSecs: tzOffsetSecs)
    }

    //
    // MARK: - Overrides for graph customization
    //

    // create and return an array of GraphDataLayer objects, w/o data, ordered in view layer from back to front (i.e., last item in array will be drawn last)
    override func graphLayers(_ viewSize: CGSize, timeIntervalForView: TimeInterval, startTime: Date, tileIndex: Int) -> [GraphDataLayer] {

        let workoutLayer = WorkoutGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, layout: self)
        
//        let mealLayer = MealGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, layout: self)
        
        let noteLayer = NoteGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, layout: self)

        let cbgLayer = CbgGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, layout: self)
        
        let smbgLayer = SmbgGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, layout: self)

        let basalLayer = BasalGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, layout: self)

        let bolusLayer = BolusGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, layout: self)

        let wizardLayer = WizardGraphDataLayer.init(viewSize: viewSize, timeIntervalForView: timeIntervalForView, startTime: startTime, layout: self)
        
        // Note these two layers are not independent!
        bolusLayer.wizardLayer = wizardLayer

        // Note: ordering is important! E.g., wizard layer draws after bolus layer so it can place circles above related bolus rectangles.
        return [workoutLayer, basalLayer, cbgLayer, noteLayer, smbgLayer, bolusLayer, wizardLayer]
    }

    // Bolus and basal values are scaled according to max value found, so the records are queried for the complete graph time range and stored here where the tiles can share them.
    var maxBolus: CGFloat = 0.0
    var maxBasal: CGFloat = 0.0
    var allBasalData: [GraphDataType]?
    var allBolusData: [GraphDataType]?
    
    func invalidateCaches() {
        allBasalData = nil
        allBolusData = nil
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
    let highBoundary: CGFloat = 180.0
    let lowBoundary: CGFloat = 80.0
    // Colors
    let highColor = Styles.purpleColor
    let targetColor = Styles.greenColor
    let lowColor = Styles.peachColor
    
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
    // Workout durations go in the header sections. Notes are in footer.
    var yTopOfWorkout: CGFloat = 0.0
    var yBottomOfWorkout: CGFloat = 0.0
    var yPixelsWorkout: CGFloat = 0.0
    var yTopOfMeal: CGFloat = 0.0
    var yBottomOfMeal: CGFloat = 0.0
    var yTopOfNote: CGFloat = 0.0
    var yBottomOfNote: CGFloat = 0.0

    //
    // MARK: - Private constants
    //
    
    fileprivate let kGraphWizardHeight: CGFloat = 27.0
    // After removing a constant height for the header and wizard values, the remaining graph vertical space is divided into four sections based on the following fractions (which should add to 1.0)
    fileprivate let kGraphFractionForGlucose: CGFloat = 180.0/266.0
    fileprivate let kGraphFractionForBolusAndBasal: CGFloat = 76.0/266.0
    // Each section has some base offset as well
    fileprivate let kGraphGlucoseBaseOffset: CGFloat = 2.0
    fileprivate let kGraphWizardBaseOffset: CGFloat = 2.0
    fileprivate let kGraphBolusBaseOffset: CGFloat = 2.0
    fileprivate let kGraphBasalBaseOffset: CGFloat = 2.0
    fileprivate let kGraphWorkoutBaseOffset: CGFloat = 2.0
    fileprivate let kGraphBottomEdge: CGFloat = 2.0
    
    //
    // MARK: - Configuration
    //

    /// Dynamic layout configuration based on view sizing
    override func configureGraph() {
        
        super.configureGraph()

        self.headerHeight = 24.0
        self.footerHeight = 20.0
        self.yAxisLineLeftMargin = 26.0
        self.yAxisLineRightMargin = 10.0
        self.yAxisLineColor = UIColor(hex: 0xe2e4e7)
        self.backgroundColor = Styles.whiteColor
        self.yAxisValuesWithLines = displayGridLines ? [80, 180] : []
        self.yAxisValuesWithLabels = [40, 80, 180, 300]
    
        self.axesLabelTextColor = Styles.alt2DarkGreyColor
        self.axesLabelTextFont = Styles.smallRegularFont
        self.axesLeftLabelTextColor = Styles.alt2DarkGreyColor
        self.axesRightLabelTextColor = Styles.alt2DarkGreyColor
        
        self.hourMarkerStrokeColor = UIColor(hex: 0xdce1f2)
        self.xLabelRegularFont = Styles.smallRegularFont
        self.xLabelLightFont = Styles.smallLightFont
        
        let graphViewHeight = ceil(graphViewSize.height) // often this is fractional
        
        // Tweak: if height is less than 320 pixels, let the wizard circles drift up into the low area of the blood glucose data since that should be clear
        let wizardHeight = graphViewHeight < 320.0 ? 0.0 : kGraphWizardHeight

        // The pie to divide is what's left over after removing constant height areas
        let graphHeight = graphViewHeight - headerHeight - wizardHeight - kGraphBottomEdge - footerHeight
        
        // Put the workout data at the top, over the X-axis
        yTopOfWorkout = 2.0
        yTopOfMeal = 0.0
        yTopOfNote = 0.0
        yBottomOfWorkout = graphViewHeight - kGraphBottomEdge
        yBottomOfMeal = yBottomOfWorkout
        yBottomOfNote = yBottomOfWorkout
        // Meal line goes from top to bottom as well
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
        self.yBottomOfBolus = graphViewHeight - footerHeight - kGraphBottomEdge
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

}
