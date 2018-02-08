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

fileprivate extension UIColor {
    func blended(withFraction fraction: CGFloat, of color: UIColor) -> UIColor {
        var r1: CGFloat = 1, g1: CGFloat = 1, b1: CGFloat = 1, a1: CGFloat = 1
        var r2: CGFloat = 1, g2: CGFloat = 1, b2: CGFloat = 1, a2: CGFloat = 1
        
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return UIColor(red: r1 * (1 - fraction) + r2 * fraction,
                       green: g1 * (1 - fraction) + g2 * fraction,
                       blue: b1 * (1 - fraction) + b2 * fraction,
                       alpha: a1 * (1 - fraction) + a2 * fraction);
    }
}

@IBDesignable class TPRowSeparatorView: UIImageView {

    override func layoutSubviews() {
        super.layoutSubviews()
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0)
        self.drawSeparatorView(frame: self.bounds)
        
        let separatorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.image = separatorImage
    }

    private func drawSeparatorView(frame: CGRect) {
        //// General Declarations
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        //// Color Declarations
        let gradientColor = UIColor(hex: 0xe4e4e5)
        let gradientColor2 = UIColor(hex: 0xf7f7f8)
        
        //// Gradient Declarations
        let gradient = CGGradient(colorsSpace: nil, colors: [gradientColor.cgColor, gradientColor.blended(withFraction: 0.5, of: gradientColor2).cgColor, gradientColor2.cgColor] as CFArray, locations: [0, 0.24, 1])!
        
        //// Rectangle Drawing
        let rectangleRect = frame
        let rectanglePath = UIBezierPath(rect: rectangleRect)
        context.saveGState()
        rectanglePath.addClip()
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: rectangleRect.midX, y: rectangleRect.minY),
                                   end: CGPoint(x: rectangleRect.midX, y: rectangleRect.maxY),
                                   options: [])
        context.restoreGState()
    }

}
