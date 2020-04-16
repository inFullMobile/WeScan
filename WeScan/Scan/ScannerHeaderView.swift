//
//  ScannerHeaderView.swift
//  WeScan
//
//  Created by Krzysztof Pelczar on 15/04/2020.
//  Copyright © 2020 WeTransfer. All rights reserved.
//

import UIKit

class ScannerHeaderView: UIView {

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Scan Contact"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 40, weight: .semibold)
        label.minimumScaleFactor = 0.5
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 1
        return label
    }()
    
    lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Business Card"
        label.textColor = .primary
        label.font = UIFont.systemFont(ofSize: 40, weight: .semibold)
        label.minimumScaleFactor = 0.5
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 1
        return label
    }()
    
    lazy var lineupLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Line it up with the frame"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.numberOfLines = 1
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(lineupLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: self.topAnchor),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: -8),
            
            lineupLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            lineupLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            lineupLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            lineupLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
}
