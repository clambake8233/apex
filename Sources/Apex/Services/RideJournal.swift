import Foundation

// MARK: - RideJournal
//
// Crash-safe persistence for an IN-PROGRESS recording. The background-location
// config keeps GPS flowing when the app is backgrounded (Google Maps / Spotify
// in front), but iOS can still TERMINATE the app under memory pressure — which a
// heavy foreground app like turn-by-turn navigation makes more likely on a long
// ride. If the live track lived only in RAM, that termination would lose the
// whole ride.
//
// RideJournal streams each sample to disk as it arrives (append-only JSON lines),
// so an unexpected termination loses at most the last fix. On next launch the app
// can detect and RECOVER the interrupted ride. `finish()` clears the journal once
// the ride is safely handed to the store.
//
// Format: line 1 is a header (ride id + start), each subsequent line is one
// sample. Append-only + line-oriented = robust to a mid-write kill (a torn last
// line is simply skipped on recovery).

// Thread-safety: all access to the mutable file handle goes through the serial
// `queue`, so the type is safe to share despite `@unchecked Sendable`.
public final class RideJournal: @unchecked Sendable {

    public static let shared = RideJournal()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.apexrides.ridejournal", qos: .utility)
    private var handle: FileHandle?

    public init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory,
                                                        in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("ride-in-progress.jsonl")
    }

    // MARK: Recording lifecycle

    /// Begin a fresh journal for a ride (truncates any prior file). Writes a header.
    public func begin(rideID: String, title: String, startedAt: Date) {
        queue.sync {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            handle = try? FileHandle(forWritingTo: fileURL)
            let header = JournalHeader(rideID: rideID, title: title, startedAt: startedAt)
            if let data = try? JSONEncoder().encode(header) {
                handle?.write(data)
                handle?.write(Self.newline)
            }
        }
    }

    /// Append one sample. Cheap, off the main thread; flushed so a kill right
    /// after loses nothing already appended.
    public func append(_ sample: RideSample) {
        queue.async { [weak self] in
            guard let self, let handle = self.handle else { return }
            let row = JournalSample(sample)
            guard let data = try? JSONEncoder().encode(row) else { return }
            handle.write(data)
            handle.write(Self.newline)
            try? handle.synchronize()   // fsync — durable across an OS kill
        }
    }

    /// Finish cleanly: close and delete the journal (ride is now saved elsewhere).
    public func finish() {
        queue.sync {
            try? handle?.close()
            handle = nil
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Block until all queued appends have been written. For tests and for a
    /// deliberate flush before reading back.
    public func flush() {
        queue.sync {}
    }

    // MARK: Recovery

    /// Is there an interrupted ride on disk from a previous (terminated) session?
    public func hasInterruptedRide() -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
            && ((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) > 0
    }

    /// Reconstruct the interrupted ride from the journal (nil if unusable). Skips
    /// a torn final line safely. Does NOT delete the file — call finish() after
    /// the recovered ride is persisted.
    public func recoverRide() -> Ride? {
        guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
        guard let headerLine = lines.first,
              let header = try? JSONDecoder().decode(JournalHeader.self,
                                                     from: Data(headerLine.utf8)) else { return nil }
        var samples: [RideSample] = []
        for line in lines.dropFirst() {
            // A torn last line (killed mid-write) just fails to decode → skipped.
            if let s = try? JSONDecoder().decode(JournalSample.self, from: Data(line.utf8)) {
                samples.append(s.rideSample)
            }
        }
        guard samples.count > 1 else { return nil }
        return Ride(id: header.rideID, title: header.title,
                    startedAt: header.startedAt, endedAt: samples.last!.timestamp,
                    samples: samples)
    }

    // MARK: Wire format

    private static let newline = Data([0x0A])

    private struct JournalHeader: Codable {
        let rideID: String
        let title: String
        let startedAt: Date
    }

    private struct JournalSample: Codable {
        let t: Double   // timestamp (epoch)
        let la: Double
        let lo: Double
        let al: Double
        let sp: Double
        init(_ s: RideSample) {
            t = s.timestamp.timeIntervalSince1970
            la = s.latitude; lo = s.longitude; al = s.altitude; sp = s.speed
        }
        var rideSample: RideSample {
            RideSample(timestamp: Date(timeIntervalSince1970: t),
                       latitude: la, longitude: lo, altitude: al, speed: sp)
        }
    }
}
