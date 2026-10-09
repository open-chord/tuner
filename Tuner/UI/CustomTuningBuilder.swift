import SwiftUI

/// The custom tuning editor owns only draft state. Its `onSave` callback asks
/// CustomTuningStore to persist the finished tuning.
struct CustomTuningBuilder: View {
    // MARK: - Draft tuning

    // `dismiss` closes the sheet after saving or cancelling.
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Мой строй"
    @State private var strings = CustomStringDraft.standard

    let onSave: (String, [GuitarString]) -> Void

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !strings.isEmpty
    }

    // MARK: - Editing form

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например, Open C", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    ForEach($strings) { $string in
                        HStack(spacing: 10) {
                            Text("\((strings.firstIndex { $0.id == string.id } ?? 0) + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 18)

                            Picker("Нота", selection: $string.note) {
                                ForEach(CustomStringDraft.notes, id: \.self) { note in
                                    Text(note).tag(note)
                                }
                            }
                            .labelsHidden()

                            Picker("Октава", selection: $string.octave) {
                                ForEach(0...7, id: \.self) { octave in
                                    Text("\(octave)").tag(octave)
                                }
                            }
                            .labelsHidden()

                            Spacer()

                            Text(string.guitarString.frequency, format: .number.precision(.fractionLength(1)))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("Hz")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .onDelete { offsets in
                        // A tuning must retain at least one string.
                        guard strings.count - offsets.count >= 1 else { return }
                        strings.remove(atOffsets: offsets)
                    }

                    Button {
                        // Copy the previous note as a convenient starting point.
                        guard strings.count < 12 else { return }
                        let previous = strings.last ?? .init(note: "E", octave: 2)
                        strings.append(.init(note: previous.note, octave: previous.octave))
                    } label: {
                        Label("Добавить струну", systemImage: "plus.circle.fill")
                    }
                    .disabled(strings.count >= 12)
                } header: {
                    Text("Струны · \(strings.count)")
                } footer: {
                    Text("Расположи струны от самой толстой к самой тонкой. Свайп влево удаляет струну.")
                }
            }
            .navigationTitle("Свой строй")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(name, strings.map(\.guitarString))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
