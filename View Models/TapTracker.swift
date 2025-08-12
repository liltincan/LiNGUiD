//
//  TapTracker.swift
//  LiNGUiD
//
//  Created by Christian Hernandez on 8/8/25.
//
import SwiftUI
import Combine

//don't allow inheritance
final class TapTracker: ObservableObject {
    //setter that will allow to use the getter
    @Published private(set) var used: Int = 0
    let max: Int
    private var currentKey: String = TapTracker.todayKey()
    private var midnightTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    //constructor
    init(maxPerDay: Int = 20) {
        self.max = maxPerDay
        self.used = Self.readUsed(for: currentKey)
        scheduleMidnightTimer()
        observeDayChangeNotifications()
    }
    //destructor that will prevent memory leaks
    deinit { midnightTimer?.invalidate() }
    
    var remaining: Int { max - used }
    
    //MARK: - Will check if it has reached the max over 20
    @discardableResult
    func tryConsume() -> Bool {
        guard used < max else { return false }
        used += 1
        Self.writeUsed(used, for: currentKey)
        return true
    }
    //MARK: - Resets when its midnight
    //preconditon: none
    //postcondition: will check if it has reached midnight if yes then create a new key for the tapping
    func resetForNewDayIfNeeded() {
        let newKey = Self.todayKey()
        guard newKey != currentKey else { return }
        currentKey = newKey
        //read the existing value for the new day (likely 0). Publish so UI updates.
        used = Self.readUsed(for: newKey)
    }

    // MARK: - Theset two functions will be scheduling the reset
    private func scheduleMidnightTimer() {
        midnightTimer?.invalidate()
        guard let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .strict,
            direction: .forward
        ) else { return }

        midnightTimer = Timer.scheduledTimer(withTimeInterval: nextMidnight.timeIntervalSinceNow,
                                             repeats: false) { [weak self] _ in
            self?.resetForNewDayIfNeeded()
            //schedule for the following midnight
            self?.scheduleMidnightTimer()
        }
        RunLoop.main.add(midnightTimer!, forMode: .common)
    }
    private func observeDayChangeNotifications() {
        //will show at midnight and for significant time changes
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification))
            .sink { [weak self] _ in self?.resetForNewDayIfNeeded() }
            .store(in: &cancellables)
    }

    // MARK: - These functions will keep track of the taps
    //function will get the date of the users taps so the year/month/day
    private static func todayKey() -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyyMMdd"
        return "translateTaps_" + df.string(from: Date())
    }
    //function will create a key
    private static func readUsed(for key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }
    private static func writeUsed(_ value: Int, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

