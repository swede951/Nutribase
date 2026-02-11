//
//  DashboardCardCell.swift
//  nutribase
//
//  UICollectionViewCell for hosting SwiftUI card views
//

import UIKit
import SwiftUI

class DashboardCardCell: UICollectionViewCell {
    
    static let reuseIdentifier = "DashboardCardCell"
    
    private var hostingController: UIHostingController<AnyView>?
    private var snapshotImageView: UIImageView?
    private var shadowContainerView: UIView?
    private var removeButton: UIButton?
    
    var onRemove: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        
        // Allow shadows and overlays to render outside cell bounds
        // (same approach that lets the remove button render at -6,-6)
        clipsToBounds = false
        contentView.clipsToBounds = false
        
        // Add shadow container (renders card shadow at UIKit layer level)
        let shadow = UIView()
        shadow.backgroundColor = .clear
        shadow.translatesAutoresizingMaskIntoConstraints = false
        shadow.layer.shadowColor = UIColor.black.cgColor
        shadow.layer.shadowOpacity = 0.08
        shadow.layer.shadowRadius = 8
        shadow.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.addSubview(shadow)
        
        NSLayoutConstraint.activate([
            shadow.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shadow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            shadow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        shadowContainerView = shadow
        
        // Add remove button
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        button.tintColor = .systemRed
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        contentView.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -6),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: -6),
            button.widthAnchor.constraint(equalToConstant: 24),
            button.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        removeButton = button
    }
    
    @objc private func removeTapped() {
        onRemove?()
    }
    
    /// Configure with a static snapshot image (stable, no SwiftUI layout)
    func configure(with image: UIImage, showRemoveButton: Bool = true) {
        // Hide hosting controller if present
        hostingController?.view.isHidden = true
        
        // Show shadow container for snapshot images
        shadowContainerView?.isHidden = false
        
        // Show/create image view
        if let imageView = snapshotImageView {
            imageView.image = image
            imageView.isHidden = false
        } else {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 16
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            // Insert above shadow container but below remove button
            if let shadow = shadowContainerView {
                contentView.insertSubview(imageView, aboveSubview: shadow)
            } else {
                contentView.insertSubview(imageView, at: 0)
            }
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            
            snapshotImageView = imageView
        }
        
        // Configure remove button visibility
        removeButton?.isHidden = !showRemoveButton
        if showRemoveButton, let button = removeButton {
            contentView.bringSubviewToFront(button)
        }
    }
    
    /// Configure with live SwiftUI view (legacy, may have layout instability)
    func configure(with view: AnyView, showRemoveButton: Bool = true) {
        // Hide snapshot image view if present
        snapshotImageView?.isHidden = true
        // Hide UIKit shadow - live SwiftUI views handle their own shadow
        shadowContainerView?.isHidden = true
        
        if let hosting = hostingController {
            hosting.view.isHidden = false
            // Reuse existing hosting controller - update rootView in-place
            hosting.rootView = view
            hosting.view.invalidateIntrinsicContentSize()
            hosting.view.setNeedsLayout()
            hosting.view.layoutIfNeeded()
        } else {
            // Create new hosting controller only if needed
            let hosting = UIHostingController(rootView: view)
            hosting.view.backgroundColor = .clear
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            hosting.view.clipsToBounds = false
            
            if #available(iOS 16.0, *) {
                hosting.sizingOptions = []
            }
            
            contentView.insertSubview(hosting.view, at: 0)
            
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            
            hostingController = hosting
        }
        
        // Configure remove button visibility
        removeButton?.isHidden = !showRemoveButton
        if showRemoveButton, let button = removeButton {
            contentView.bringSubviewToFront(button)
        }
    }
    
    func setEditingChromeHidden(_ hidden: Bool) {
        removeButton?.isHidden = hidden
    }
    
    func setInteractionEnabled(_ enabled: Bool) {
        hostingController?.view.isUserInteractionEnabled = enabled
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep shadow path in sync with cell size for performance
        shadowContainerView?.layer.shadowPath = UIBezierPath(
            roundedRect: contentView.bounds,
            cornerRadius: 16
        ).cgPath
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // Clear snapshot
        snapshotImageView?.image = nil
        // Prevent old SwiftUI state flashing during reuse
        hostingController?.rootView = AnyView(EmptyView())
        onRemove = nil
        removeButton?.isHidden = false
    }
}
