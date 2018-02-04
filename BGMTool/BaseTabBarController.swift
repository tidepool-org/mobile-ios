//
//  BaseTabBarController.swift
//  BGMTool
//
//  Copyright © 2018 Tidepool. All rights reserved.
//

import UIKit

class BaseTabBarController: UITabBarController, UITabBarControllerDelegate {
    
    /// Remember last tab selected...
    var lastSelectedTab: Int? {
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: kLastSelectedTabKey)
            _lastSelectedTab = nil
        }
        get {
            if _lastSelectedTab == nil {
                let curValue = UserDefaults.standard.object(forKey: kLastSelectedTabKey)
                if let tab = curValue as? Int {
                    _lastSelectedTab = tab
                }
            }
            return _lastSelectedTab
        }
    }
    private var _lastSelectedTab: Int?
    private let kLastSelectedTabKey = "kLastSelectedTabKey"

    override func viewDidLoad() {
        super.viewDidLoad()
        let index = lastSelectedTab ?? 0
        selectedIndex = index
        // delegate to self!
        self.delegate = self
    }
    
    //
    // MARK: - UITabBarControllerDelegate methods
    //
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        lastSelectedTab = selectedIndex
    }
    
}
