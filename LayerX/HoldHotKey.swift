//
//  HoldHotKey.swift
//  LayerX
//
//  A system-wide hot key that reports both press and release, so callers can
//  act for as long as the combination is held. Uses the Carbon hot key API,
//  which needs no Accessibility permission.
//

import Cocoa
import Carbon.HIToolbox

final class HoldHotKey {

	var onPress: (() -> Void)?
	var onRelease: (() -> Void)?

	private(set) var shortcut: Shortcut?
	private(set) var isHeld = false

	private var hotKeyRef: EventHotKeyRef?
	private var handlerRef: EventHandlerRef?
	private var watchdog: Timer?

	private static let signature: OSType = 0x4C59_5258 // "LYRX"

	init() {
		var specs = [
			EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
			EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
		]

		InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
			guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }
			let hotKey = Unmanaged<HoldHotKey>.fromOpaque(userData).takeUnretainedValue()

			switch Int(GetEventKind(event)) {
			case kEventHotKeyPressed: hotKey.pressed()
			case kEventHotKeyReleased: hotKey.released()
			default: return OSStatus(eventNotHandledErr)
			}
			return noErr
		}, specs.count, &specs, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
	}

	deinit {
		unregister()
		if let handlerRef = handlerRef {
			RemoveEventHandler(handlerRef)
		}
	}

	/// Registers `shortcut`, replacing any previous one.
	/// Returns false when the system refuses it (typically: already taken).
	@discardableResult
	func register(_ shortcut: Shortcut) -> Bool {
		unregister()

		let id = EventHotKeyID(signature: HoldHotKey.signature, id: 1)
		let status = RegisterEventHotKey(
			UInt32(shortcut.keyCode),
			UInt32(shortcut.carbonModifiers),
			id,
			GetEventDispatcherTarget(),
			0,
			&hotKeyRef
		)

		guard status == noErr, hotKeyRef != nil else {
			hotKeyRef = nil
			return false
		}

		self.shortcut = shortcut
		return true
	}

	func unregister() {
		if let hotKeyRef = hotKeyRef {
			UnregisterEventHotKey(hotKeyRef)
		}
		hotKeyRef = nil
		shortcut = nil
		released()
	}

	// MARK: Press / release

	private func pressed() {
		guard !isHeld else { return }
		isHeld = true
		startWatchdog()
		onPress?()
	}

	private func released() {
		guard isHeld else { return }
		isHeld = false
		watchdog?.invalidate()
		watchdog = nil
		onRelease?()
	}

	/// Carbon only reports the release of the key itself. Polling the keyboard
	/// state also ends the hold when a modifier is let go first, and covers a
	/// release event that never arrives.
	private func startWatchdog() {
		watchdog?.invalidate()
		let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			if !self.isCombinationDown {
				self.released()
			}
		}
		RunLoop.main.add(timer, forMode: .common)
		watchdog = timer
	}

	private var isCombinationDown: Bool {
		guard let shortcut = shortcut else { return false }

		guard CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(shortcut.keyCode)) else {
			return false
		}

		let flags = CGEventSource.flagsState(.combinedSessionState)
		return flags.contains(Shortcut.cgFlags(forCarbonModifiers: shortcut.carbonModifiers))
	}
}

// MARK: - Modifier conversions

extension Shortcut {

	static func carbonModifiers(for flags: NSEvent.ModifierFlags) -> Int {
		var result = 0
		if flags.contains(.command) { result |= cmdKey }
		if flags.contains(.option) { result |= optionKey }
		if flags.contains(.control) { result |= controlKey }
		if flags.contains(.shift) { result |= shiftKey }
		return result
	}

	static func cgFlags(forCarbonModifiers modifiers: Int) -> CGEventFlags {
		var result: CGEventFlags = []
		if modifiers & cmdKey != 0 { result.insert(.maskCommand) }
		if modifiers & optionKey != 0 { result.insert(.maskAlternate) }
		if modifiers & controlKey != 0 { result.insert(.maskControl) }
		if modifiers & shiftKey != 0 { result.insert(.maskShift) }
		return result
	}

	/// Builds a shortcut from a key-down event, or nil if the event is not a
	/// usable combination (it needs a modifier, unless it is a function key).
	init?(event: NSEvent) {
		let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
		let keyCode = Int(event.keyCode)
		let isFunctionKey = Shortcut.functionKeyNames[keyCode] != nil

		guard !flags.isEmpty || isFunctionKey else { return nil }

		var display = ""
		if flags.contains(.control) { display += "⌃" }
		if flags.contains(.option) { display += "⌥" }
		if flags.contains(.shift) { display += "⇧" }
		if flags.contains(.command) { display += "⌘" }

		if let name = Shortcut.functionKeyNames[keyCode] ?? Shortcut.specialKeyNames[keyCode] {
			display += name
		} else if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
			display += characters.uppercased()
		} else {
			display += "Key \(keyCode)"
		}

		self.init(keyCode: keyCode, carbonModifiers: Shortcut.carbonModifiers(for: flags), display: display)
	}

	private static let functionKeyNames: [Int: String] = [
		kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
		kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
		kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
		kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
	]

	private static let specialKeyNames: [Int: String] = [
		kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
		kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
		kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
		kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
		kVK_ANSI_KeypadEnter: "⌤",
	]
}
