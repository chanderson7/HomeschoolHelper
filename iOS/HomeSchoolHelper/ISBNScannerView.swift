import SwiftUI
import VisionKit
import HomeschoolCore

// MARK: - Book Lookup Result

struct BookLookupResult {
    var isbn: String
    var title: String
    var author: String
    var totalPages: Int?
    var genre: String?
}

// MARK: - Open Library Fetcher

actor OpenLibraryFetcher {
    static func lookup(isbn: String) async -> BookLookupResult? {
        let urlString = "https://openlibrary.org/isbn/\(isbn).json"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json else { return nil }

            let title = (json["title"] as? String) ?? ""
            guard !title.isEmpty else { return nil }

            // Resolve authors (may be key references like /authors/OL123A)
            var authorName = "Unknown Author"
            if let authorRefs = json["authors"] as? [[String: Any]],
               let firstKey = authorRefs.first?["key"] as? String {
                let authorURL = URL(string: "https://openlibrary.org\(firstKey).json")
                if let authorURL,
                   let (aData, _) = try? await URLSession.shared.data(from: authorURL),
                   let aJson = try? JSONSerialization.jsonObject(with: aData) as? [String: Any],
                   let name = aJson["name"] as? String {
                    authorName = name
                }
            }

            let pages = json["number_of_pages"] as? Int

            // Subjects → genre (take first if available)
            let subjects = json["subjects"] as? [String]
            let genre = subjects?.first

            return BookLookupResult(
                isbn: isbn,
                title: title,
                author: authorName,
                totalPages: pages,
                genre: genre
            )
        } catch {
            return nil
        }
    }
}

// MARK: - DataScanner UIViewControllerRepresentable

@available(iOS 16.0, *)
struct ISBNScannerView: UIViewControllerRepresentable {
    var onISBNScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .qr])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onISBNScanned: onISBNScanned)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onISBNScanned: (String) -> Void
        private var didScan = false

        init(onISBNScanned: @escaping (String) -> Void) {
            self.onISBNScanned = onISBNScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didScan else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue {
                    // Accept EAN-13 (13 digits) or EAN-8 / UPC (8 digits)
                    let digits = payload.filter(\.isNumber)
                    guard digits.count >= 8 else { continue }
                    didScan = true
                    let haptic = UINotificationFeedbackGenerator()
                    haptic.notificationOccurred(.success)
                    DispatchQueue.main.async { self.onISBNScanned(digits) }
                    return
                }
            }
        }
    }
}

// MARK: - ISBN Scanner Sheet

struct ISBNScannerSheet: View {
    var onBookSelected: (BookLookupResult) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scannedISBN: String? = nil
    @State private var lookupResult: BookLookupResult? = nil
    @State private var isLooking = false
    @State private var lookupError: String? = nil
    @State private var scannerAvailable = false

    var body: some View {
        NavigationStack {
            ZStack {
                if scannerAvailable {
                    scannerLayer
                } else {
                    unavailableView
                }

                VStack {
                    Spacer()
                    if isLooking {
                        lookingUpCard
                    } else if let result = lookupResult {
                        resultCard(result)
                    } else if let error = lookupError {
                        errorCard(error)
                    } else {
                        instructionCard
                    }
                }
                .padding()
            }
            .ignoresSafeArea(edges: .top)
            .navigationTitle("Scan Book Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            if #available(iOS 16.0, *) {
                scannerAvailable = DataScannerViewController.isAvailable && DataScannerViewController.isSupported
            }
        }
        .onChange(of: scannedISBN) { _, isbn in
            guard let isbn else { return }
            lookupResult = nil
            lookupError = nil
            isLooking = true
            Task {
                if let result = await OpenLibraryFetcher.lookup(isbn: isbn) {
                    await MainActor.run {
                        lookupResult = result
                        isLooking = false
                    }
                } else {
                    await MainActor.run {
                        lookupError = "Couldn't find book info for ISBN \(isbn). You can enter details manually."
                        isLooking = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scannerLayer: some View {
        if #available(iOS 16.0, *) {
            ISBNScannerView { isbn in
                scannedISBN = isbn
            }
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Camera Unavailable")
                .font(.title2.bold())
            Text("Barcode scanning requires a physical device with a camera and iOS 16 or later.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var instructionCard: some View {
        VStack(spacing: 10) {
            Label("Point the camera at the barcode on the back of the book", systemImage: "barcode.viewfinder")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var lookingUpCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Looking up book info…")
                .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func resultCard(_ result: BookLookupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Book Found", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title).font(.title3.bold())
                Text(result.author).foregroundStyle(.secondary)
                if let pages = result.totalPages {
                    Text("\(pages) pages").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button("Use This Book") {
                onBookSelected(result)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            Button("Scan Again") {
                scannedISBN = nil
                lookupResult = nil
                lookupError = nil
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Not Found", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Scan Again") {
                scannedISBN = nil
                lookupError = nil
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
