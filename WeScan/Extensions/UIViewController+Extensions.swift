//
//  UIViewController+Extensions.swift
//  WeScan
//
//  Created by Krzysztof Pelczar on 13/05/2020.
//  Copyright © 2020 WeTransfer. All rights reserved.
//

import UIKit

extension UIViewController {
    
    func setupBackButton() {
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
}
