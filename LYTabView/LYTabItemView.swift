//
//  LYTabBarCellView.swift
//  LYTabBarView
//
//  Created by Lu Yibin on 16/3/30.
//  Copyright © 2016年 Lu Yibin. All rights reserved.
//

import Foundation
import Cocoa



class LYTabItemView: NSButton {
    fileprivate let titleView = NSTextField(frame: .zero)
    fileprivate var closeButton: LYHoverButton?

    var canClose: Bool = true
    var tabBarView: LYTabBarView!
    var tabLabelObserver: NSKeyValueObservation?
    var tabViewItem: NSTabViewItem? {
        didSet {
            setupTitleAccordingToItem()
        }
    }
    var drawBorder = false {
        didSet {
            self.needsDisplay = true
        }
    }

    // hover effect
    private var hovered = false
    private var trackingArea: NSTrackingArea?

    // style
    var xpadding: CGFloat = 4
    var ypadding: CGFloat = 2
    var closeButtonSize = NSSize(width: 16, height: 16)
    var backgroundColor: ColorConfig = [
        .active: NSColor(deviceRed: 241/255.0, green: 243/255.0, blue: 245/255.0, alpha: 0.8),
        .windowInactive: NSColor(deviceRed: 241/255.0, green: 243/255.0, blue: 245/255.0, alpha: 0.8),
        .inactive: NSColor(deviceRed: 241/255.0, green: 243/255.0, blue: 245/255.0, alpha: 0.8)
    ]

    var hoverBackgroundColor: ColorConfig = [
        .active: NSColor(white: 0.75, alpha: 1),
        .windowInactive: NSColor(white: 0.94, alpha: 1),
        .inactive: NSColor(white: 0.68, alpha: 1)
    ]

    @objc dynamic private var realBackgroundColor = NSColor(deviceRed: 241/255.0, green: 243/255.0, blue: 245/255.0, alpha: 0.8) {
        didSet {
            needsDisplay = true
        }
    }
    static var selectedBackgroundColor: ColorConfig = [
        .active: NSColor(white: 1.0, alpha: 1),
        .windowInactive: NSColor(white: 0.96, alpha: 1),
        .inactive: NSColor(white: 0.76, alpha: 1)
    ]

    var selectedTextColor: ColorConfig = [
        .active: NSColor.textColor,
        .windowInactive: NSColor(white: 0.4, alpha: 1),
        .inactive: NSColor(white: 0.4, alpha: 1)
    ]

    var unselectedForegroundColor = NSColor(white: 0.4, alpha: 1)
    var closeButtonHoverBackgroundColor = NSColor(white: 0.55, alpha: 0.3)

    override var title: String {
        get {
            return titleView.stringValue
        }
        set(newTitle) {
            titleView.stringValue = newTitle as String
            self.invalidateIntrinsicContentSize()
        }
    }

    var isMoving = false

    private var shouldDrawInHighLight: Bool {
        if let tabViewItem = self.tabViewItem {
            return tabViewItem.tabState == .selectedTab && !isDragging
        }
        return false
    }

    private var needAnimation: Bool {
        return self.tabBarView.needAnimation
    }
 
    override static func defaultAnimation(forKey key: NSAnimatablePropertyKey) -> Any? {
        if key.rawValue == "realBackgroundColor" {
            return CABasicAnimation()
        }
        return super.defaultAnimation(forKey: key) as AnyObject?
    }

    // Drag and Drop
    var dragOffset: CGFloat?
    var isDragging = false
    var draggingView: NSImageView?
    var draggingViewLeadingConstraint: NSLayoutConstraint?

    func setupViews() {
        self.isBordered = false
        let lowerPriority = NSLayoutConstraint.Priority(rawValue: NSLayoutConstraint.Priority.defaultLow.rawValue-10)
        self.setContentHuggingPriority(lowerPriority, for: .horizontal)
        
        titleView.wantsLayer = true

        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.isEditable = false
        titleView.alignment = .center
        titleView.isBordered = false
        titleView.drawsBackground = false
        self.addSubview(titleView)
        let padding = xpadding * 2 + closeButtonSize.width
        titleView.trailingAnchor
            .constraint(greaterThanOrEqualTo: self.trailingAnchor, constant: -padding).isActive = true
        titleView.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: padding).isActive = true
        titleView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        titleView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        titleView.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor, constant: ypadding).isActive = true
        titleView.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor, constant: -ypadding).isActive = true
        titleView.setContentHuggingPriority(lowerPriority, for: .horizontal)
        titleView.setContentCompressionResistancePriority(NSLayoutConstraint.Priority.defaultLow, for: .horizontal)
        titleView.lineBreakMode = .byTruncatingTail
        
        if canClose, let ttitle = self.tabViewItem!.identifier as? String, ttitle != "home" {
            closeButton = LYTabCloseButton(frame: .zero)
            closeButton?.translatesAutoresizingMaskIntoConstraints = false
            closeButton?.hoverBackgroundColor = closeButtonHoverBackgroundColor
            closeButton?.target = self
            closeButton?.action = #selector(closeTab)
            closeButton?.heightAnchor.constraint(equalToConstant: closeButtonSize.height).isActive = true
            closeButton?.widthAnchor.constraint(equalToConstant: closeButtonSize.width).isActive = true
            closeButton?.isHidden = true
            self.addSubview(closeButton!)
            closeButton?.trailingAnchor
                .constraint(greaterThanOrEqualTo: self.titleView.leadingAnchor, constant: -xpadding).isActive = true
            closeButton?.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor, constant: ypadding).isActive = true
            closeButton?.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: xpadding + 5).isActive = true
            closeButton?.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            closeButton?.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor, constant: -ypadding).isActive = true
        }
        
        let menu = NSMenu()
        let addMenuItem = NSMenuItem(title: NSLocalizedString("New Tab", comment: "New Tab"),
                                     action: #selector(addNewTab), keyEquivalent: "")
        addMenuItem.target = self
        menu.addItem(addMenuItem)
        let closeMenuItem = NSMenuItem(title: NSLocalizedString("Close Tab", comment: "Close Tab"),
                                       action: #selector(closeTab), keyEquivalent: "")
        closeMenuItem.target = self
        menu.addItem(closeMenuItem)
        let closeOthersMenuItem = NSMenuItem(title: NSLocalizedString("Close other Tabs",
                                                                      comment: "Close other Tabs"),
                                             action: #selector(closeOtherTabs), keyEquivalent: "")
        closeOthersMenuItem.target = self
        menu.addItem(closeOthersMenuItem)

        let closeToRightMenuItem = NSMenuItem(title: "Close Tabs to the Right",
                                              action: #selector(closeToRight),
                                              keyEquivalent: "")
        closeToRightMenuItem.target = self
        menu.addItem(closeToRightMenuItem)

        menu.delegate = self
        self.menu = menu
    }

    func setupTitleAccordingToItem() {
        if let item = self.tabViewItem {
            tabLabelObserver = item.observe(\.label) { _, _ in
                if let item = self.tabViewItem {
                    self.title = item.label
                }
            }
            self.title = item.label
        }
    }
    
    private func buildBarButton(image: NSImage?) -> NSView {
        let imageView = NSImageView(frame: .zero)
        imageView.image = image
        return imageView
    }

    override var intrinsicContentSize: NSSize {
        var size = titleView.intrinsicContentSize
        if let ttitle = tabViewItem?.identifier as? String, ttitle == "home" {
            size = closeButtonSize
        }
        
        size.height += ypadding * 2
        if let minHeight = self.tabBarView.minTabHeight, size.height < minHeight {
            size.height = minHeight
        }
        size.width += xpadding * 3 + closeButtonSize.width
        return size
    }

    convenience init(tabViewItem: NSTabViewItem) {
        self.init(frame: .zero)
        self.tabViewItem = tabViewItem
        setupViews()
        setupTitleAccordingToItem()
        if let ttitle = tabViewItem.identifier as? String, ttitle == "home" {
            let button = buildBarButton(image: NSImage(named: NSImage.Name(rawValue: "home")))
            button.translatesAutoresizingMaskIntoConstraints = false
//            button.isEnabled = false
            let padding = xpadding*2+closeButtonSize.width/2.0
            self.addSubview(button)
            button.trailingAnchor
                .constraint(greaterThanOrEqualTo: self.trailingAnchor, constant: -padding).isActive = true
            button.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: padding).isActive = true
            button.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
            button.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            button.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor, constant: ypadding).isActive = true
            button.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor, constant: -ypadding).isActive = true
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    func drawCanvas2(fillColor: NSColor, frame: NSRect = NSRect(x: 0, y: 0, width: 82, height: 30)) {
        //// Bezier Drawing
        let bezierPath = NSBezierPath()
        bezierPath.move(to: NSPoint(x: frame.minX + 4, y: frame.minY + 7.19))
        /*
         bezierPath.move(to: NSPoint(x: frame.minX + 4, y: frame.minY + 7.19))
         
             bezierPath.curve(to: NSPoint(x: frame.minX + 4.44, y: frame.minY + 3.11),
         controlPoint1: NSPoint(x: frame.minX + 4, y: frame.minY + 5.02),
         controlPoint2: NSPoint(x: frame.minX + 4, y: frame.minY + 3.94))
         
             bezierPath.curve(to: NSPoint(x: frame.minX + 6.18, y: frame.minY + 1.42),
         controlPoint1: NSPoint(x: frame.minX + 4.82, y: frame.minY + 2.38),
         controlPoint2: NSPoint(x: frame.minX + 5.43, y: frame.minY + 1.79))
         
             bezierPath.curve(to: NSPoint(x: frame.minX + 10.4, y: frame.minY + 1),
         controlPoint1: NSPoint(x: frame.minX + 7.04, y: frame.minY + 1),
         controlPoint2: NSPoint(x: frame.minX + 8.16, y: frame.minY + 1))

         */
        // top-left corner
        bezierPath.curve(to: NSPoint(x: frame.minX + 4.44, y: frame.minY + 3.11),
                         controlPoint1: NSPoint(x: frame.minX + 4, y: frame.minY + 5.02),
                         controlPoint2: NSPoint(x: frame.minX + 4, y: frame.minY + 3.94))
        bezierPath.curve(to: NSPoint(x: frame.minX + 6.18, y: frame.minY + 1.42),
                         controlPoint1: NSPoint(x: frame.minX + 4.82, y: frame.minY + 2.38),
                         controlPoint2: NSPoint(x: frame.minX + 5.43, y: frame.minY + 1.79))
        bezierPath.curve(to: NSPoint(x: frame.minX + 10.4, y: frame.minY + 1),
                         controlPoint1: NSPoint(x: frame.minX + 7.04, y: frame.minY + 1),
                         controlPoint2: NSPoint(x: frame.minX + 8.16, y: frame.minY + 1))
        
        //bezierPath.line(to: NSPoint(x: frame.minX + 71.6, y: frame.minY + 1))
        bezierPath.line(to: NSPoint(x: frame.width - (82 - 71.6), y: frame.minY + 1)) //top line
        
        // top-right corner
        
        /*
         bezierPath.curve(to: NSPoint(x: frame.minX + 75.82, y: frame.minY + 1.42),
         controlPoint1: NSPoint(x: frame.minX + 73.84, y: frame.minY + 1),
         controlPoint2: NSPoint(x: frame.minX + 74.96, y: frame.minY + 1))
         
             bezierPath.curve(to: NSPoint(x: frame.minX + 77.56, y: frame.minY + 3.11),
         controlPoint1: NSPoint(x: frame.minX + 76.57, y: frame.minY + 1.79),
         controlPoint2: NSPoint(x: frame.minX + 77.18, y: frame.minY + 2.38))
         
             bezierPath.curve(to: NSPoint(x: frame.minX + 78, y: frame.minY + 7.19),
         controlPoint1: NSPoint(x: frame.minX + 78, y: frame.minY + 3.94),
         controlPoint2: NSPoint(x: frame.minX + 78, y: frame.minY + 5.02))
           
         */
        
        bezierPath.curve(to: NSPoint(x: frame.width - (82 - 75.82), y: frame.minY + 1.42),
                         controlPoint1: NSPoint(x: frame.width - (82 - 73.84), y: frame.minY + 1),
                         controlPoint2: NSPoint(x: frame.width - (82 - 74.96), y: frame.minY + 1))
        bezierPath.curve(to: NSPoint(x: frame.width - (82 - 77.56), y: frame.minY + 3.11),
                         controlPoint1: NSPoint(x: frame.width - (82 - 76.57), y: frame.minY + 1.79),
                         controlPoint2: NSPoint(x: frame.width - (82 - 77.18), y: frame.minY + 2.38))
        bezierPath.curve(to: NSPoint(x: frame.width - (82 - 78), y: frame.minY + 7.19),
                         controlPoint1: NSPoint(x: frame.width - (82 - 78), y: frame.minY + 3.94),
                         controlPoint2: NSPoint(x: frame.width - (82 - 78), y: frame.minY + 5.02))
        
        //     bezierPath.line(to: NSPoint(x: frame.minX + 78, y: frame.minY + 23.74))
        bezierPath.line(to: NSPoint(x: frame.width - (82 - 78), y: frame.height - (30 - 23.74))) //right line
        
        
        /*
         bezierPath.curve(to: NSPoint(x: frame.minX + 78.04, y: frame.minY + 25.14),
         controlPoint1: NSPoint(x: frame.minX + 78, y: frame.minY + 24.46),
         controlPoint2: NSPoint(x: frame.minX + 78, y: frame.minY + 24.81))
         
             bezierPath.curve(to: NSPoint(x: frame.minX + 80.72, y: frame.minY + 29.34),
         controlPoint1: NSPoint(x: frame.minX + 78.24, y: frame.minY + 26.86),
         controlPoint2: NSPoint(x: frame.minX + 79.23, y: frame.minY + 28.4))
         
             bezierPath.curve(to: NSPoint(x: frame.minX + 82, y: frame.minY + 30),
         controlPoint1: NSPoint(x: frame.minX + 81.01, y: frame.minY + 29.52),
         controlPoint2: NSPoint(x: frame.minX + 81.34, y: frame.minY + 29.68))

         */
        // botom-right corner
        bezierPath.curve(to: NSPoint(x: frame.width - (82 - 78.04), y: frame.height - (30 - 25.14)),
                         controlPoint1: NSPoint(x: frame.width - (82 -  78), y: frame.height - (30 - 24.46)),
                         controlPoint2: NSPoint(x: frame.width - (82 -  78), y: frame.height - (30 - 24.81)))
        bezierPath.curve(to: NSPoint(x: frame.width - (82 - 80.72), y: frame.height - (30 - 29.34)),
                         controlPoint1: NSPoint(x: frame.width - (82 - 78.24), y: frame.height - (30 - 26.86)),
                         controlPoint2: NSPoint(x: frame.width - (82 - 79.23), y: frame.height - (30 - 28.4)))
        bezierPath.curve(to: NSPoint(x: frame.width, y: frame.minY + frame.height),
                         controlPoint1: NSPoint(x: frame.width - (82 - 81.01), y: frame.height - (30 - 29.52)),
                         controlPoint2: NSPoint(x: frame.width - (82 -  81.34), y: frame.height - (30 - 29.68)))
        
        bezierPath.line(to: NSPoint(x: frame.minX, y: frame.minY + frame.height)) // bottom line
        
        /*
         bezierPath.curve(to: NSPoint(x: frame.minX + 1.28, y: frame.minY + 29.34),
         controlPoint1: NSPoint(x: frame.minX + 0.66, y: frame.minY + 29.68),
         controlPoint2: NSPoint(x: frame.minX + 0.99, y: frame.minY + 29.52))
         
            bezierPath.curve(to: NSPoint(x: frame.minX + 3.96, y: frame.minY + 25.14),
         controlPoint1: NSPoint(x: frame.minX + 2.77, y: frame.minY + 28.4),
         controlPoint2: NSPoint(x: frame.minX + 3.76, y: frame.minY + 26.86))
         
            bezierPath.curve(to: NSPoint(x: frame.minX + 4, y: frame.minY + 23.74),
         controlPoint1: NSPoint(x: frame.minX + 4, y: frame.minY + 24.81),
         controlPoint2: NSPoint(x: frame.minX + 4, y: frame.minY + 24.46))
         
            bezierPath.line(to: NSPoint(x: frame.minX + 4, y: frame.minY + 7.19))
         */
        // bottom left corner
        bezierPath.curve(to: NSPoint(x: frame.minX + 1.28, y: frame.height - (30 - 29.34)),
                         controlPoint1: NSPoint(x: frame.minX + 0.66, y: frame.height - (30 - 29.68)),
                         controlPoint2: NSPoint(x: frame.minX + 0.99, y: frame.height - (30 -  29.52)))
        bezierPath.curve(to: NSPoint(x: frame.minX + 3.96, y: frame.height - (30 -  25.14)),
                         controlPoint1: NSPoint(x: frame.minX + 2.77, y: frame.height - (30 - 28.4)),
                         controlPoint2: NSPoint(x: frame.minX + 3.76, y: frame.height - (30 - 26.86)))
        bezierPath.curve(to: NSPoint(x: frame.minX + 4, y: frame.height - (30 -  23.74)),
                         controlPoint1: NSPoint(x: frame.minX + 4, y: frame.height - (30 -  24.81)),
                         controlPoint2: NSPoint(x: frame.minX + 4, y: frame.height - (30 -  24.46)))
        bezierPath.line(to: NSPoint(x: frame.minX + 4, y: frame.minY + 7.19)) //left line
        
        bezierPath.close()
        fillColor.setFill()
        bezierPath.fill()
    }

    func drawCanvas1(fillColor: NSColor, frame: NSRect = NSRect(x: 0, y: 0, width: 82, height: 30)) {

        //// Bezier Drawing
        let bezierPath = NSBezierPath()
        bezierPath.move(to: NSPoint(x: 0, y: frame.height))
        bezierPath.curve(to: NSPoint(x: 2, y: frame.height - 2.18),
                         controlPoint1: NSPoint(x: 2, y: frame.height - 3.18),
                         controlPoint2: NSPoint(x: 2, y: frame.height - 4))
        bezierPath.curve(to: NSPoint(x: 3, y: frame.height - 2.18),
                         controlPoint1: NSPoint(x: 3, y: frame.height - 4.18),
                         controlPoint2: NSPoint(x: 3, y: frame.height - 5))
        bezierPath.curve(to: NSPoint(x: 5, y: frame.height - 5.18),
                         controlPoint1: NSPoint(x: 5, y: frame.height - 6),
                         controlPoint2: NSPoint(x: 5, y: frame.height - 6.18))
        bezierPath.line(to: NSPoint(x: 5, y: 5)) // left line
        bezierPath.curve(to: NSPoint(x: 6, y: 4), controlPoint1: NSPoint(x: 7, y: 3.6), controlPoint2: NSPoint(x: 8, y: 3))
        bezierPath.line(to: NSPoint(x: frame.width - 6, y: 3)) // top line
        bezierPath.curve(to: NSPoint(x: frame.width - 5, y: 4), controlPoint1: NSPoint(x: frame.width - 6, y: 4.5), controlPoint2: NSPoint(x: frame.width - 5.5, y: 5))
        
        bezierPath.line(to: NSPoint(x: frame.width - 5, y: 0)) // right line
        bezierPath.curve(to: NSPoint(x: frame.width - 4, y: frame.height - 2.18), controlPoint1: NSPoint(x:  frame.width - 4, y: frame.height - 3.18), controlPoint2: NSPoint(x: frame.width - 4, y: frame.height - 4))
        bezierPath.curve(to: NSPoint(x: frame.width, y: frame.height), controlPoint1: NSPoint(x: frame.width - 1, y: frame.height - 3), controlPoint2: NSPoint(x: frame.width - 2, y: frame.height - 2))
        bezierPath.line(to: NSPoint(x: 0, y: frame.height))
        bezierPath.close() // bottom line
        fillColor.setFill()
        bezierPath.fill()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let status = self.tabBarView.status
        if shouldDrawInHighLight {
            
//            NSColor.green.setFill()
//            self.bounds.fill()
            titleView.textColor = selectedTextColor[status]!
            self.drawCanvas2(fillColor: LYTabItemView.selectedBackgroundColor[.active]!, frame: self.bounds)
            
            if self.drawBorder {
                let boderFrame = self.bounds.insetBy(dx: 1, dy: -1)
                self.tabBarView.borderColor[status]!.setStroke()
                let path = NSBezierPath(rect: boderFrame)
                path.stroke()
            }
            
        } else {
            self.realBackgroundColor.setFill()
            titleView.textColor = unselectedForegroundColor
        }

    }

    override func mouseDown(with theEvent: NSEvent) {
        if let tabViewItem = self.tabViewItem {
            self.tabBarView.selectTabViewItem(tabViewItem)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        self.trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(self.trackingArea!)
    }

    override func mouseEntered(with theEvent: NSEvent) {
        if hovered {
            return
        }
        hovered = true
        let status = self.tabBarView.status
        if !shouldDrawInHighLight {
            self.animatorOrNot(needAnimation).realBackgroundColor = hoverBackgroundColor[status]!
        }
        closeButton?.animatorOrNot(needAnimation).isHidden = false
    }

    override func mouseExited(with theEvent: NSEvent) {
        if !hovered {
            return
        }
        hovered = false
        let status = self.tabBarView.status
        if !shouldDrawInHighLight {
            self.animatorOrNot(needAnimation).realBackgroundColor = backgroundColor[status]!
        }
        closeButton?.animatorOrNot(needAnimation).isHidden = true
    }

    override func mouseDragged(with theEvent: NSEvent) {
        if !isDragging {
            setupDragAndDrop(theEvent)
        }
    }

    func updateColors() {
        let status = self.tabBarView.status
        if hovered {
            self.realBackgroundColor = hoverBackgroundColor[status]!
        } else {
            self.realBackgroundColor = backgroundColor[status]!
        }
    }

    override func viewDidMoveToWindow() {
        self.updateColors()
    }

    @IBAction func addNewTab(_ sender: AnyObject?) {
        if let target = self.tabBarView.addNewTabButtonTarget, let action = self.tabBarView.addNewTabButtonAction {
            _ = target.perform(action, with: self)
        }
    }

    @IBAction func closeTab(_ sender: AnyObject?) {
        if let tabViewItem = self.tabViewItem {
            self.tabBarView.removeTabViewItem(tabViewItem, animated: true)
        }
    }

    @IBAction func closeOtherTabs(_ send: AnyObject?) {
        if let tabViewItem = self.tabViewItem {
            self.tabBarView.removeAllTabViewItemExcept(tabViewItem)
        }
    }

    @IBAction func closeToRight(_ sender: Any) {
        if let tabViewItem = self.tabViewItem {
            self.tabBarView.removeFrom(tabViewItem)
        }
    }
}

extension LYTabItemView: NSPasteboardItemDataProvider {
    func pasteboard(_ pasteboard: NSPasteboard?,
                    item: NSPasteboardItem,
                    provideDataForType type: NSPasteboard.PasteboardType) {
    }
}

extension LYTabItemView: NSDraggingSource {
    func setupDragAndDrop(_ theEvent: NSEvent) {
        return
        let pasteItem = NSPasteboardItem()
        let dragItem = NSDraggingItem(pasteboardWriter: pasteItem)
        var draggingRect = self.frame
        draggingRect.size.width = 1
        draggingRect.size.height = 1
        let dummyImage = NSImage(size: NSSize(width: 1, height: 1))
        dragItem.setDraggingFrame(draggingRect, contents: dummyImage)
        let draggingSession = self.beginDraggingSession(with: [dragItem], event: theEvent, source: self)
        draggingSession.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        if context == .withinApplication {
            return .move
        }
        return NSDragOperation()
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        return true
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        dragOffset = self.frame.origin.x - screenPoint.x
        closeButton?.isHidden = true
        let dragRect = self.bounds
        let image = NSImage(data: self.dataWithPDF(inside: dragRect))
        self.draggingView = NSImageView(frame: dragRect)
        if let draggingView = self.draggingView {
            draggingView.image = image
            draggingView.translatesAutoresizingMaskIntoConstraints = false
            self.tabBarView.addSubview(draggingView)
            draggingView.topAnchor.constraint(equalTo: self.tabBarView.topAnchor).isActive = true
            draggingView.bottomAnchor.constraint(equalTo: self.tabBarView.bottomAnchor).isActive = true
            draggingView.widthAnchor.constraint(equalToConstant: self.frame.width)
            self.draggingViewLeadingConstraint = draggingView.leadingAnchor
                .constraint(equalTo: self.tabBarView.tabContainerView.leadingAnchor, constant: self.frame.origin.x)
            self.draggingViewLeadingConstraint?.isActive = true
        }
        isDragging = true
        self.titleView.isHidden = true
        self.needsDisplay = true
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        if let constraint = self.draggingViewLeadingConstraint,
            let offset = self.dragOffset, let draggingView = self.draggingView {
            var constant = screenPoint.x + offset
            let min: CGFloat = 0
            if constant < min {
                constant = min
            }
            let max = self.tabBarView.tabContainerView.frame.size.width - self.frame.size.width
            if constant > max {
                constant = max
            }
            constraint.constant = constant

            self.tabBarView.handleDraggingTab(draggingView.frame, dragTabItemView: self)
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragOffset = nil
        isDragging = false
        
        if canClose {
            closeButton?.isHidden = false
        }
        
        self.titleView.isHidden = false
        self.draggingView?.removeFromSuperview()
        self.draggingViewLeadingConstraint = nil
        self.needsDisplay = true
        if let tabViewItem = self.tabViewItem {
            self.tabBarView.updateTabViewForMovedTabItem(tabViewItem)
        }
    }
}

extension LYTabItemView: NSMenuDelegate {
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(addNewTab) {
            return (self.tabBarView.addNewTabButtonTarget != nil) && (self.tabBarView.addNewTabButtonAction != nil)
        }
        if menuItem.action == #selector(closeToRight) {
            if let tabItem = self.tabViewItem,
                let tabView = self.tabViewItem?.tabView {
                return tabItem != tabView.tabViewItems.last
            }
            return false
        }
        return true
    }
}
