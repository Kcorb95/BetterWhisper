import SwiftUI

struct HistoryView: View {
    let historyStore: HistoryStore
    @State private var searchText = ""
    @State private var selectedRecord: TranscriptionRecord?
    @State private var showDeleteConfirmation = false
    @State private var showClearConfirmation = false
    @State private var copiedRecordID: UUID?

    private var filteredRecords: [TranscriptionRecord] {
        if searchText.isEmpty {
            return historyStore.records
        }
        return historyStore.search(query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if historyStore.records.isEmpty {
                emptyState
            } else {
                HSplitView {
                    recordsList
                        .frame(minWidth: 250, idealWidth: 300)

                    detailView
                        .frame(minWidth: 300, idealWidth: 400)
                }
            }
        }
        .frame(minWidth: 650, minHeight: 400)
        .alert("Clear History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                historyStore.clear()
                selectedRecord = nil
            }
        } message: {
            Text("This will permanently delete all transcription history. This action cannot be undone.")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search transcriptions...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Spacer()

            Text("\(filteredRecords.count) record\(filteredRecords.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button {
                showClearConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .disabled(historyStore.records.isEmpty)
            .help("Clear all history")
        }
        .padding(10)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No transcriptions yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Hold your hotkey to record, and transcriptions will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Records List

    private var recordsList: some View {
        List(filteredRecords, selection: $selectedRecord) { record in
            RecordRow(
                record: record,
                isSelected: selectedRecord?.id == record.id,
                isCopied: copiedRecordID == record.id,
                onCopy: { copyRecord(record) },
                onDelete: { deleteRecord(record) }
            )
            .tag(record)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail View

    private var detailView: some View {
        Group {
            if let record = selectedRecord {
                RecordDetailView(
                    record: record,
                    isCopied: copiedRecordID == record.id,
                    onCopy: { copyRecord(record) },
                    onCopyRaw: { copyText(record.rawText) },
                    onDelete: { deleteRecord(record) }
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Select a transcription to view details")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Actions

    private func copyRecord(_ record: TranscriptionRecord) {
        copyText(record.displayText)
        copiedRecordID = record.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedRecordID == record.id {
                copiedRecordID = nil
            }
        }
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func deleteRecord(_ record: TranscriptionRecord) {
        if selectedRecord?.id == record.id {
            selectedRecord = nil
        }
        historyStore.delete(id: record.id)
    }
}

// MARK: - Record Row

struct RecordRow: View {
    let record: TranscriptionRecord
    let isSelected: Bool
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.formattedDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Text(record.mode.capitalized)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Text(record.formattedDuration)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Text(record.preview(maxLength: 120))
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Copy") { onCopy() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Record Detail View

struct RecordDetailView: View {
    let record: TranscriptionRecord
    let isCopied: Bool
    let onCopy: () -> Void
    let onCopyRaw: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.formattedDate)
                            .font(.headline)

                        HStack(spacing: 8) {
                            Label(record.mode.capitalized, systemImage: "wand.and.stars")
                                .font(.system(size: 11))
                                .foregroundStyle(.blue)

                            Label(record.formattedDuration, systemImage: "timer")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            onCopy()
                        } label: {
                            Label(isCopied ? "Copied!" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isCopied ? .green : .blue)

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }

                Divider()

                // Processed text (if available)
                if let processed = record.processedText {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Processed Text")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(processed)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // Raw text
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Raw Transcription")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        if record.processedText != nil {
                            Button("Copy Raw") { onCopyRaw() }
                                .font(.system(size: 10))
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                        }
                    }

                    Text(record.rawText)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)
        }
    }
}
