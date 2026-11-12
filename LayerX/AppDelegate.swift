//
//  AppDelegate.swift
//  LayerX
//
//  Created by Michael Chen on 2015/10/26.
//  Copyright © 2015年 Michael Chen. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	private let defaultSize = NSMakeSize(480, 320)
	private let resizeStep: CGFloat = 0.1

	var allSpaces = false
	var locked = false
	var onTop = false

	weak var window: MCWIndow!
	weak var viewController: ViewController!
	var isLockIconHiddenWhileLocked = false {
		didSet { viewController.lockIconImageView.isHidden = window.isMovable || isLockIconHiddenWhileLocked }
	}
	var isSizeHidden = false {
		didSet { viewController.sizeTextField.isHidden = isSizeHidden }
	}

	private let backdrop = BackdropWindow()
	private let holdHotKey = HoldHotKey()
	private var preferences: PreferencesWindowController?

	/// True while the hold-to-show shortcut is pressed.
	private var isHolding = false

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		Settings.registerDefaults()

		if let window = NSApp.windows.first(where: { $0 is MCWIndow }) as? MCWIndow {
			window.fitsWithSize(defaultSize)
			self.window = window
			applyWindowPresentation()
		}

		let center = NotificationCenter.default
		for name in [NSWindow.didChangeScreenNotification, NSWindow.didBecomeKeyNotification] {
			center.addObserver(self, selector: #selector(syncBackdrop), name: name, object: window)
		}
		center.addObserver(self, selector: #selector(syncBackdrop), name: NSApplication.didChangeScreenParametersNotification, object: nil)
		center.addObserver(self, selector: #selector(syncBackdrop), name: NSApplication.didBecomeActiveNotification, object: nil)

		holdHotKey.onPress = { [weak self] in self?.holdBegan() }
		holdHotKey.onRelease = { [weak self] in self?.holdEnded() }
		if let shortcut = Settings.holdShortcut {
			holdHotKey.register(shortcut)
		}

		syncBackdrop()
	}

	/// Clicking the Dock icon brings back an overlay hidden by the shortcut.
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		showOverlay(nil)
		return false
	}
}

// MARK: - Overlay presentation

extension AppDelegate {

	/// Derives the window level and Spaces behaviour from the current state.
	/// While the shortcut is held the overlay floats above everything, on
	/// whichever Space (including full-screen apps) is active.
	private func applyWindowPresentation() {
		let elevated = onTop || locked || isHolding
		let levelKey: CGWindowLevelKey = elevated ? .maximumWindow : .normalWindow
		window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(levelKey)))

		if isHolding {
			window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
		} else if allSpaces {
			window.collectionBehavior = [.canJoinAllSpaces]
		} else {
			window.collectionBehavior = [.managed, .moveToActiveSpace]
		}

		syncBackdrop()
	}

	@objc private func syncBackdrop() {
		guard let window = window else { return }
		backdrop.sync(with: window)
	}

	private func holdBegan() {
		isHolding = true
		applyWindowPresentation()
		// Show without activating LayerX, so the app in use keeps focus.
		window.orderFrontRegardless()
		syncBackdrop()
	}

	private func holdEnded() {
		isHolding = false
		window.orderOut(nil)
		applyWindowPresentation()
	}

	@IBAction func showOverlay(_ sender: AnyObject?) {
		window.makeKeyAndOrderFront(nil)
		syncBackdrop()
	}

	@IBAction func toggleBackground(_ sender: AnyObject?) {
		Settings.backgroundEnabled = !Settings.backgroundEnabled
		preferences?.reload()
		syncBackdrop()
	}

	@IBAction func showPreferences(_ sender: AnyObject?) {
		if preferences == nil {
			let controller = PreferencesWindowController()
			controller.delegate = self
			preferences = controller
		}
		preferences?.reload()
		NSApp.activate(ignoringOtherApps: true)
		preferences?.showWindow(nil)
		preferences?.window?.makeKeyAndOrderFront(nil)
	}
}

// MARK: - PreferencesDelegate

extension AppDelegate: PreferencesDelegate {

	func preferencesDidChangeBackground() {
		syncBackdrop()
	}

	func preferencesDidChangeShortcut(_ shortcut: Shortcut?) -> Bool {
		guard let shortcut = shortcut else {
			holdHotKey.unregister()
			Settings.holdShortcut = nil
			return true
		}

		guard holdHotKey.register(shortcut) else {
			// Keep the previous shortcut working.
			if let previous = Settings.holdShortcut {
				holdHotKey.register(previous)
			}
			return false
		}

		Settings.holdShortcut = shortcut
		return true
	}

	func preferencesIsRecordingShortcut(_ recording: Bool) {
		if recording {
			holdHotKey.unregister()
		} else if let shortcut = Settings.holdShortcut {
			holdHotKey.register(shortcut)
		}
	}
}

fileprivate enum ArrowTag: Int {
	case up = 20
	case left = 21
	case right = 22
	case down = 23
}

// MARK: - Hotkeys

extension AppDelegate {

	private var originalSize: NSSize {
		viewController.imageView.image?.size ?? defaultSize
	}

	private func resizeAspectFit(calculator: (_ original: CGFloat, _ current: CGFloat) -> CGFloat) {
		let originalSize = self.originalSize
		let width = calculator(originalSize.width, window.frame.size.width)
		let height = width / originalSize.width * originalSize.height

		if width > 0 {
			window.resizeTo(NSSize(width: width, height: height), animated: true)
		}
	}

	@IBAction func actualSize(_ sender: AnyObject?) {
		window.resizeTo(originalSize, animated: true)
	}

	@IBAction func makeLarger(_ sender: AnyObject) {
		resizeAspectFit { $0 * ($1 / $0 + resizeStep) }
	}

	@IBAction func makeSmaller(_ sender: AnyObject) {
		resizeAspectFit { $0 * ($1 / $0 - resizeStep) }
	}

	@IBAction func makeLargerOnePixel(_ sender: AnyObject) {
		resizeAspectFit { $1 + 1 }
	}

	@IBAction func makeSmallerOnePixel(_ sender: AnyObject) {
		resizeAspectFit { $1 - 1 }
	}

	@IBAction func increaseTransparency(_ sender: AnyObject) {
		var alpha = viewController.imageView.alphaValue
		alpha -= 0.1
		viewController.imageView.alphaValue = max(alpha, 0.05)
	}

	@IBAction func reduceTransparency(_ sender: AnyObject) {
		var alpha = viewController.imageView.alphaValue
		alpha += 0.1
		viewController.imageView.alphaValue = min(alpha, 1.0)
	}
	
	func getPasteboardImage() -> NSImage? {
		let pasteboard = NSPasteboard.general;
		if let file = pasteboard.data(forType: NSPasteboard.PasteboardType.fileURL),
		   let str = String(data: file, encoding: .utf8),
		   let url = URL(string: str)
		{
			return NSImage(contentsOf: url)
		}

		if let tiff = pasteboard.data(forType: NSPasteboard.PasteboardType.tiff) {
			return NSImage(data: tiff)
		}

		if let png = pasteboard.data(forType: NSPasteboard.PasteboardType.png) {
			return NSImage(data: png)
		}

		return nil
	}
	
	@IBAction func paste(_ sender: AnyObject) {
		guard let image = getPasteboardImage() else { return }
		let rep = image.representations[0]
		viewController.imageView.image = image
		let size = NSMakeSize(CGFloat(rep.pixelsWide), CGFloat(rep.pixelsHigh))
		window.resizeTo(size, animated: true)
		viewController.sizeTextField.isHidden = false
		viewController.placeholderTextField.isHidden = true

	}
	
	@IBAction func toggleLockWindow(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		locked = !locked
		onTop = locked
		if locked {
			menuItem.title  = "Unlock"
			window.isMovable = false
			window.ignoresMouseEvents = true
		} else {
			menuItem.title  = "Lock"
			window.isMovable = true
			window.ignoresMouseEvents = false
		}
		applyWindowPresentation()

		viewController.lockIconImageView.isHidden = window.isMovable || isLockIconHiddenWhileLocked
	}
	
	@IBAction func toggleOnTop(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		onTop = !onTop
		if onTop {
			menuItem.title = "Don't keep on top"
		} else if !locked {
			menuItem.title = "Keep on top"
		}
		applyWindowPresentation()
	}
	
	@IBAction func toggleLockIconVisibility(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		menuItem.state = menuItem.state == .on ? .off : .on
		isLockIconHiddenWhileLocked = menuItem.state == .on
	}

	@IBAction func toggleSizeVisibility(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		menuItem.state = menuItem.state == .on ? .off : .on
		isSizeHidden = menuItem.state == .on
	}

	@IBAction func moveAround(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem

		guard let arrow = ArrowTag(rawValue: menuItem.tag) else {
			return
		}

		switch arrow {
		case .up:
			window.moveBy(CGPoint(x: 0, y: 1))
		case .left:
			window.moveBy(CGPoint(x: -1, y: 0))
		case .right:
			window.moveBy(CGPoint(x: 1, y: 0))
		case .down:
			window.moveBy(CGPoint(x: 0, y: -1))
		}
	}

	@IBAction func toggleAllSpaces(_ sender: AnyObject) {
		let menuItem = sender as! NSMenuItem
		allSpaces = !allSpaces
		if allSpaces {
			menuItem.title = "Keep on this space"
		} else {
			menuItem.title = "Keep on all spaces"
		}
		applyWindowPresentation()
	}

	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.action {
		case #selector(showPreferences(_:)), #selector(showOverlay(_:)):
			return true
		case #selector(toggleBackground(_:)):
			menuItem.state = Settings.backgroundEnabled ? .on : .off
			return true
		default:
			break
		}

		return viewController.imageView.image != nil
	}
}

// MARK: - Helper

func appDelegate() -> AppDelegate {
	return NSApp.delegate as! AppDelegate
}
