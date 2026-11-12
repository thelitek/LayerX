//
//  BackdropWindow.swift
//  LayerX
//
//  A click-through window that fills the screen behind the image.
//

import Cocoa

final class BackdropWindow: NSWindow {

	init() {
		super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
		isOpaque = false
		hasShadow = false
		ignoresMouseEvents = true
		isReleasedWhenClosed = false
		animationBehavior = .none
		refreshColor()
	}

	override var canBecomeKey: Bool { false }
	override var canBecomeMain: Bool { false }

	/// Re-reads colour and opacity from `Settings`.
	func refreshColor() {
		backgroundColor = Settings.backgroundColor.withAlphaComponent(CGFloat(Settings.backgroundOpacity))
	}

	/// Shows the backdrop directly behind `window`, filling that window's screen,
	/// or hides it when the backdrop is disabled or `window` is not on screen.
	func sync(with window: NSWindow) {
		guard Settings.backgroundEnabled, window.isVisible,
			  let screen = window.screen ?? NSScreen.main else {
			orderOut(nil)
			return
		}

		refreshColor()
		level = window.level
		collectionBehavior = window.collectionBehavior
		setFrame(screen.frame, display: true)
		order(.below, relativeTo: window.windowNumber)
	}
}
