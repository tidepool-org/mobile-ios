//
//  TPIntrinsicSizeUIView.swift
//  TidepoolMobile
//
//  Created by Larry Kenyon on 4/27/17.
//  Copyright © 2017 Tidepool. All rights reserved.
//

import UIKit

@IBDesignable
class TPIntrinsicSizeUIView: UIView {

    @IBInspectable var height: CGFloat = 200.0 {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.bounds.width, height: height)
    }

}
