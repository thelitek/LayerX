//
//  Settings.swift
//  LayerX
//
//  User-configurable options persisted in UserDefaults.
//

import Cocoa

/// A global key combination: a virtual key code plus Carbon modifier flags.
struct Shortcut: Equatable {
	var keyCode: Int
	var carbonModifiers: Int
	/// Human-readable form, e.g. "⌃⌥Space".
	var display: String
}

enum Settings {
	private enum Key {
		static let backgroundEnabled = "backgroundEnabled"
		static let backgroundColor = "backgroundColor"
		static let backgroundOpacity = "backgroundOpacity"
		static let shortcutKeyCode = "holdShortcutKeyCode"
		static let shortcutModifiers = "holdShortcutModifiers"
		static let shortcutDisplay = "holdShortcutDisplay"
	}

	private static var defaults: UserDefaults { .standard }

	static func registerDefaults() {
		defaults.register(defaults: [
			Key.backgroundEnabled: false,
			Key.backgroundOpacity: 0.5,
		])
	}

	/// Whether the full-screen background is drawn behind the image.
	static var backgroundEnabled: Bool {
		get { defaults.bool(forKey: Key.backgroundEnabled) }
		set { defaults.set(newValue, forKey: Key.backgroundEnabled) }
	}

	/// Background colour, without its opacity (see `backgroundOpacity`).
	static var backgroundColor: NSColor {
		get {
			guard let rgb = defaults.array(forKey: Key.backgroundColor) as? [Double], rgb.count == 3 else {
				return .black
			}
			return NSColor(srgbRed: CGFloat(rgb[0]), green: CGFloat(rgb[1]), blue: CGFloat(rgb[2]), alpha: 1)
		}
		set {
			guard let color = newValue.usingColorSpace(.sRGB) else { return }
			defaults.set(
				[Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent)],
				forKey: Key.backgroundColor
			)
		}
	}

	/// Background opacity: 0 is fully transparent, 1 is solid.
	static var backgroundOpacity: Double {
		get { min(max(defaults.double(forKey: Key.backgroundOpacity), 0), 1) }
		set { defaults.set(min(max(newValue, 0), 1), forKey: Key.backgroundOpacity) }
	}

	/// The hold-to-show shortcut, or nil when none is set.
	static var holdShortcut: Shortcut? {
		get {
			guard defaults.object(forKey: Key.shortcutKeyCode) != nil,
				  let display = defaults.string(forKey: Key.shortcutDisplay) else {
				return nil
			}
			return Shortcut(
				keyCode: defaults.integer(forKey: Key.shortcutKeyCode),
				carbonModifiers: defaults.integer(forKey: Key.shortcutModifiers),
				display: display
			)
		}
		set {
			guard let shortcut = newValue else {
				defaults.removeObject(forKey: Key.shortcutKeyCode)
				defaults.removeObject(forKey: Key.shortcutModifiers)
				defaults.removeObject(forKey: Key.shortcutDisplay)
				return
			}
			defaults.set(shortcut.keyCode, forKey: Key.shortcutKeyCode)
			defaults.set(shortcut.carbonModifiers, forKey: Key.shortcutModifiers)
			defaults.set(shortcut.display, forKey: Key.shortcutDisplay)
		}
	}
}
