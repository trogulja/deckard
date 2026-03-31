import AppKit

/// A chip-based text field for entering Claude CLI arguments with autocomplete.
final class ClaudeArgsField: NSView {

    var onChange: ((String) -> Void)?

    private var chips: [ArgsChip] = []
    private let chipContainer = NSView()
    private let textField = NSTextField()
    private var chipViews: [NSView] = []
    private var selectedChipIndex: Int?
    var pendingFlag: ClaudeFlag?

    var stringValue: String {
        get { ArgsChip.serialize(chips) }
        set { loadChips(from: newValue) }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateBorderColor()

        chipContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chipContainer)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textField.focusRingType = .none
        textField.placeholderString = "Type a flag name..."
        textField.delegate = self
        textField.cell?.sendsActionOnEndEditing = false
        addSubview(textField)

        NSLayoutConstraint.activate([
            chipContainer.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            chipContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            chipContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),

            textField.topAnchor.constraint(equalTo: chipContainer.bottomAnchor, constant: 2),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            textField.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorderColor()
    }

    private func updateBorderColor() {
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    // MARK: - Chip Management

    private func loadChips(from string: String) {
        chips = ArgsChip.deserialize(string, knownFlags: ClaudeCLIFlags.shared.flags)
        rebuildChipViews()
    }

    func addChip(_ chip: ArgsChip) {
        chips.append(chip)
        rebuildChipViews()
        onChange?(stringValue)
    }

    private func removeChip(at index: Int) {
        guard index >= 0 && index < chips.count else { return }
        chips.remove(at: index)
        selectedChipIndex = nil
        rebuildChipViews()
        onChange?(stringValue)
    }

    private func rebuildChipViews() {
        chipViews.forEach { $0.removeFromSuperview() }
        chipViews.removeAll()

        chipContainer.constraints.filter { $0.firstAttribute == .height }.forEach { $0.isActive = false }

        guard !chips.isEmpty else {
            chipContainer.heightAnchor.constraint(equalToConstant: 0).isActive = true
            textField.placeholderString = "Type a flag name..."
            return
        }

        textField.placeholderString = ""

        var x: CGFloat = 0
        var y: CGFloat = 0
        let spacing: CGFloat = 4
        let maxWidth = bounds.width - 12

        for (i, chip) in chips.enumerated() {
            let view = makeChipView(chip, index: i)
            let size = view.fittingSize
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += size.height + spacing
            }
            view.frame = NSRect(x: x, y: y, width: size.width, height: size.height)
            chipContainer.addSubview(view)
            chipViews.append(view)
            x += size.width + spacing
        }

        let totalHeight = y + (chipViews.last?.frame.height ?? 0)
        chipContainer.heightAnchor.constraint(equalToConstant: totalHeight).isActive = true
    }

    private func makeChipView(_ chip: ArgsChip, index: Int) -> NSView {
        let label: String
        if let value = chip.value {
            label = "\(chip.flag) \(value)"
        } else {
            label = chip.flag
        }

        let button = NSButton(title: label, target: self, action: #selector(chipClicked(_:)))
        button.tag = index
        button.bezelStyle = .inline
        button.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        button.isBordered = true
        button.wantsLayer = true
        button.layer?.cornerRadius = 4

        if selectedChipIndex == index {
            button.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
            button.contentTintColor = .white
        }

        return button
    }

    @objc private func chipClicked(_ sender: NSButton) {
        if selectedChipIndex == sender.tag {
            selectedChipIndex = nil
        } else {
            selectedChipIndex = sender.tag
        }
        rebuildChipViews()
        window?.makeFirstResponder(textField)
    }

    // MARK: - Keyboard Handling

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 /* Backspace */ {
            if let idx = selectedChipIndex {
                removeChip(at: idx)
                return
            }
            if textField.stringValue.isEmpty && !chips.isEmpty {
                selectedChipIndex = chips.count - 1
                rebuildChipViews()
                return
            }
        }
        if event.keyCode == 53 /* Escape */ {
            selectedChipIndex = nil
            rebuildChipViews()
        }
        super.keyDown(with: event)
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        rebuildChipViews()
    }
}

// MARK: - NSTextFieldDelegate

extension ClaudeArgsField: NSTextFieldDelegate {}
