//
//  PreferencesWindowController.swift
//  LayerX
//
//  Background and hold-to-show shortcut settings.
//

import Cocoa
import Carbon.HIToolbox

protocol PreferencesDelegate: AnyObject {
	/// Background enabled / colour / opacity changed.
	func preferencesDidChangeBackground()
	/// The user picked or cleared the shortcut. Return false if it could not be registered.
	func preferencesDidChangeShortcut(_ shortcut: Shortcut?) -> Bool
	/// The recorder is capturing keys; the live hot key must not fire meanwhile.
	func preferencesIsRecordingShortcut(_ recording: Bool)
}

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {

	weak var delegate: PreferencesDelegate?

	private let enabledCheckbox = NSButton(checkboxWithTitle: "Cover the full screen behind the image", target: nil, action: nil)
	private let colorWell = NSColorWell()
	private let opacitySlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
	private let opacityLabel = NSTextField(labelWithString: "50%")
	private let recorder = ShortcutRecorderButton()
	private let clearButton = NSButton(title: "Clear", target: nil, action: nil)
	private let statusLabel = NSTextField(wrappingLabelWithString: "")

	private static let hint = "Hold the shortcut to show the overlay from any app. Releasing it hides the overlay again."

	init() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 440, height: 220),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: true
		)
		window.title = "LayerX Preferences"
		window.isReleasedWhenClosed = false
		super.init(window: window)
		window.delegate = self

		buildContent(in: window)
		reload()
		window.center()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	// MARK: Layout

	private func buildContent(in window: NSWindow) {
		enabledCheckbox.target = self
		enabledCheckbox.action = #selector(enabledChanged(_:))

		colorWell.target = self
		colorWell.action = #selector(colorChanged(_:))
		colorWell.widthAnchor.constraint(equalToConstant: 56).isActive = true
		colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true

		opacitySlider.target = self
		opacitySlider.action = #selector(opacityChanged(_:))
		opacitySlider.isContinuous = true
		opacitySlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
		opacityLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

		recorder.widthAnchor.constraint(equalToConstant: 170).isActive = true
		recorder.onRecordingChanged = { [weak self] recording in
			self?.delegate?.preferencesIsRecordingShortcut(recording)
		}
		recorder.onChange = { [weak self] shortcut in
			self?.shortcutChanged(shortcut)
		}

		clearButton.bezelStyle = .rounded
		clearButton.target = self
		clearButton.action = #selector(clearShortcut(_:))

		statusLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
		statusLabel.textColor = .secondaryLabelColor
		statusLabel.preferredMaxLayoutWidth = 300

		let opacityRow = NSStackView(views: [opacitySlider, opacityLabel])
		let shortcutRow = NSStackView(views: [recorder, clearButton])

		let grid = NSGridView(views: [
			[NSTextField(labelWithString: "Background:"), enabledCheckbox],
			[NSTextField(labelWithString: "Color:"), colorWell],
			[NSTextField(labelWithString: "Opacity:"), opacityRow],
			[NSTextField(labelWithString: "Hold shortcut:"), shortcutRow],
			[NSGridCell.emptyContentView, statusLabel],
		])
		grid.translatesAutoresizingMaskIntoConstraints = false
		grid.column(at: 0).xPlacement = .trailing
		grid.rowAlignment = .firstBaseline
		grid.row(at: 1).rowAlignment = .none
		grid.row(at: 1).yPlacement = .center
		grid.row(at: 3).topPadding = 12
		grid.rowSpacing = 10
		grid.columnSpacing = 10

		let content = NSView()
		content.addSubview(grid)
		NSLayoutConstraint.activate([
			grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
			grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
			grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
			grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
		])
		window.contentView = content
	}

	/// Refreshes every control from `Settings`.
	func reload() {
		enabledCheckbox.state = Settings.backgroundEnabled ? .on : .off
		colorWell.color = Settings.backgroundColor
		opacitySlider.doubleValue = Settings.backgroundOpacity
		opacityLabel.stringValue = "\(Int((Settings.backgroundOpacity * 100).rounded()))%"
		recorder.shortcut = Settings.holdShortcut
		clearButton.isEnabled = Settings.holdShortcut != nil
		if statusLabel.stringValue.isEmpty {
			showHint()
		}
	}

	private func showHint() {
		statusLabel.stringValue = PreferencesWindowController.hint
		statusLabel.textColor = .secondaryLabelColor
	}

	// MARK: Actions

	@objc private func enabledChanged(_ sender: NSButton) {
		Settings.backgroundEnabled = sender.state == .on
		delegate?.preferencesDidChangeBackground()
	}

	@objc private func colorChanged(_ sender: NSColorWell) {
		Settings.backgroundColor = sender.color
		delegate?.preferencesDidChangeBackground()
	}

	@objc private func opacityChanged(_ sender: NSSlider) {
		Settings.backgroundOpacity = sender.doubleValue
		opacityLabel.stringValue = "\(Int((sender.doubleValue * 100).rounded()))%"
		delegate?.preferencesDidChangeBackground()
	}

	@objc private func clearShortcut(_ sender: Any?) {
		shortcutChanged(nil)
	}

	private func shortcutChanged(_ shortcut: Shortcut?) {
		let registered = delegate?.preferencesDidChangeShortcut(shortcut) ?? false

		if let shortcut = shortcut, !registered {
			statusLabel.stringValue = "\(shortcut.display) could not be registered. It is probably used by macOS or another app; try a different combination."
			statusLabel.textColor = .systemRed
		} else {
			showHint()
		}

		reload()
	}

	// MARK: NSWindowDelegate

	func windowDidResignKey(_ notification: Notification) {
		recorder.cancelRecording()
	}

	func windowWillClose(_ notification: Notification) {
		recorder.cancelRecording()
		if NSColorPanel.sharedColorPanelExists {
			NSColorPanel.shared.close()
		}
	}
}

// MARK: - Shortcut recorder

/// A button that, once clicked, captures the next key combination.
/// Escape cancels and Delete clears the current shortcut.
final class ShortcutRecorderButton: NSButton {

	var onChange: ((Shortcut?) -> Void)?
	var onRecordingChanged: ((Bool) -> Void)?

	var shortcut: Shortcut? {
		didSet { updateTitle() }
	}

	private var monitor: Any?
	private var isRecording: Bool { monitor != nil }

	init() {
		super.init(frame: .zero)
		bezelStyle = .rounded
		setButtonType(.momentaryPushIn)
		target = self
		action = #selector(toggleRecording(_:))
		updateTitle()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	deinit {
		if let monitor = monitor {
			NSEvent.removeMonitor(monitor)
		}
	}

	private func updateTitle() {
		if isRecording {
			title = "Type shortcut…"
		} else {
			title = shortcut?.display ?? "Click to record"
		}
	}

	@objc private func toggleRecording(_ sender: Any?) {
		if isRecording {
			cancelRecording()
		} else {
			startRecording()
		}
	}

	private func startRecording() {
		guard monitor == nil else { return }

		onRecordingChanged?(true)
		// A local monitor sees the event before menus do, so combinations such
		// as ⌘L are captured instead of triggering their menu item.
		monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
			guard let self = self else { return event }
			self.handle(event)
			return nil
		}
		updateTitle()
	}

	func cancelRecording() {
		guard let monitor = monitor else { return }
		NSEvent.removeMonitor(monitor)
		self.monitor = nil
		updateTitle()
		onRecordingChanged?(false)
	}

	private func handle(_ event: NSEvent) {
		let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
		let keyCode = Int(event.keyCode)

		if flags.isEmpty && keyCode == kVK_Escape {
			cancelRecording()
			return
		}

		if flags.isEmpty && (keyCode == kVK_Delete || keyCode == kVK_ForwardDelete) {
			cancelRecording()
			onChange?(nil)
			return
		}

		guard let shortcut = Shortcut(event: event) else {
			NSSound.beep()
			return
		}

		cancelRecording()
		onChange?(shortcut)
	}
}
