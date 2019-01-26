//
//  BoldFont.swift
//  I can see
//
//  Created by Daniel Foldi on 2019. 01. 26..
//  Copyright © 2019. Daniel Foldi. All rights reserved.
//

import UIKit

extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}
