import SwiftUI
import EventKit
import Foundation

// MARK: - Models
struct User: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var lovedCuisines: [String]
    var wantToTryCuisines: [String]
    var preferredDays: [Int]
    var friends: [User]
    var availableTimes: [AvailableTime]
    var availabilityStartTime: Date
    var availabilityEndTime: Date
    var receivedInvitations: [Invitation] = []
    var sentInvitations: [Invitation] = []
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}


struct YelpResponse: Decodable {
    let businesses: [Restaurant]
}


struct AvailableTime: Identifiable {
    let id = UUID()
    var date: Date
    var startTime: Date
    var endTime: Date
    var weekday: Int
}


struct Restaurant: Decodable, Identifiable {
    let id: String
    let name: String
    let rating: Double
    let location: Location
    let imageUrl: String
    let reviewCount: Int
    let price: String?
    let categories: [Category]
    let phone: String
    let url: String
    let isClosed: Bool
    let businessHours: [BusinessHours]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, rating, location, phone, url, categories, price
        case imageUrl = "image_url"
        case reviewCount = "review_count"
        case isClosed = "is_closed"
        case businessHours = "business_hours"
    }
}

struct BusinessHours: Decodable {
    let open: [OpenHours]
    let hoursType: String
    let isOpenNow: Bool
    
    enum CodingKeys: String, CodingKey {
        case open
        case hoursType = "hours_type"
        case isOpenNow = "is_open_now"
    }
}

struct OpenHours: Decodable {
    let start: String
    let end: String
    let day: Int
    let isOvernight: Bool
    
    enum CodingKeys: String, CodingKey {
        case start, end, day
        case isOvernight = "is_overnight"
    }
}

struct OpeningHours: Decodable {
    let start: String
    let end: String
    let day: Int
}

struct Location: Decodable {
    let address1: String
    let city: String
    let displayAddress: [String]
    
    enum CodingKeys: String, CodingKey {
        case address1, city
        case displayAddress = "display_address"
    }
}

struct Category: Decodable {
    let title: String
}

struct Invitation: Identifiable {
    let id = UUID()
    let from: User
    var to: [User]
    let restaurant: Restaurant
    let proposedStartTime: Date
    let proposedEndTime: Date
    var enableForwarding: Bool
    var includeRandos: Bool
    var participants: [Participant]
}

struct Participant: Identifiable {
    let id = UUID()
    let user: User
    var response: InvitationStatus
}

struct RecommendedOuting: Identifiable {
    let id = UUID()
    let restaurant: Restaurant
    let date: Date
}

enum InvitationStatus: String {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"
}

enum OverlapStatus {
    case full
    case partial
    case none
}

struct GroupRecommendedOuting: Identifiable {
    let id = UUID()
    let restaurant: Restaurant
    let participants: [User]
    let bestTimeSlot: (startTime: Date, endTime: Date)
    let groupScore: Double
}


// MARK: - ViewModel
class ContentViewModel: ObservableObject {
    @Published var currentUser: User
    @Published var users: [User] = [] // All users in the app
    @Published var restaurants: [Restaurant] = []
    //@Published var recommendedOutings: [Restaurant] = []
    @Published var sentInvitations: [Invitation] = []
    @Published var receivedInvitations: [Invitation] = []
    @Published var recommendedOutings: [RecommendedOuting] = []
    @Published var upcomingEvents: [Invitation] = []
    @Published var selectedLocation: String = "New York" {
        didSet {
            fetchRestaurants()
        }
    }
    @Published var groupRecommendedOutings: [GroupRecommendedOuting] = []
    
    let locations = ["New York", "Boston", "Chicago"]
    
    let eventStore = EKEventStore()
    
    init() {
        let calendar = Calendar.current
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        let defaultStart = calendar.date(from: DateComponents(hour: 17, minute: 0))!
        let defaultEnd = calendar.date(from: DateComponents(hour: 0, minute: 0))!
        
        // Mock user data
        self.currentUser = User(
            name: "John Doe",
            lovedCuisines: ["Italian", "Japanese"],
            wantToTryCuisines: ["Thai", "Indian"],
            preferredDays: [5, 6], // For example, prefers Friday and Saturday
            friends: [],
            availableTimes: [],
            availabilityStartTime: defaultStart,
            availabilityEndTime: defaultEnd
        )
        
        // Sample dates for testing
        let date1 = calendar.date(byAdding: .day, value: 1, to: now)!
        let date2 = calendar.date(byAdding: .day, value: 1, to: now)!
        
        // Define time slots
        let timeSlot1Start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date1)!
        let timeSlot1End = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: date1)!
        let timeSlot2Start = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: date2)!
        let timeSlot2End = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date2)!
        let timeSlot3Start = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date2)!
        let timeSlot3End = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: date2)!
        
        // Initialize other users with hardcoded availability
        /*let user1 = User(
         name: "Alice Williams",
         lovedCuisines: ["French", "Thai"],
         wantToTryCuisines: ["Korean"],
         preferredDays: [calendar.component(.weekday, from: date1) - 1],
         friends: [],
         availableTimes: [
         AvailableTime(date: date1, startTime: timeSlot1Start, endTime: timeSlot1End, weekday: calendar.component(.weekday, from: date1) - 1)
         ],
         availabilityStartTime: timeSlot1Start,
         availabilityEndTime: timeSlot1End
         )
         
         let user2 = User(
         name: "David Brown",
         lovedCuisines: ["Mexican"],
         wantToTryCuisines: ["Indian"],
         preferredDays: [calendar.component(.weekday, from: date2) - 1],
         friends: [],
         availableTimes: [
         AvailableTime(date: date2, startTime: timeSlot2Start, endTime: timeSlot2End, weekday: calendar.component(.weekday, from: date2) - 1)
         ],
         availabilityStartTime: timeSlot2Start,
         availabilityEndTime: timeSlot2End
         )
         
         let user3 = User(
         name: "Pranav",
         lovedCuisines: ["Indian", "Thai"],
         wantToTryCuisines: ["Korean", "Italian"],
         preferredDays: [calendar.component(.weekday, from: date1) - 1],
         friends: [],
         availableTimes: [
         AvailableTime(date: date1, startTime: timeSlot3Start, endTime: timeSlot3End, weekday: calendar.component(.weekday, from: date1) - 1)
         ],
         availabilityStartTime: timeSlot1Start,
         availabilityEndTime: timeSlot1End
         )
         
         // Add users to the users array
         self.users = [currentUser, user1, user2, user3]
         
         // Set up friendships
         self.currentUser.friends = [user1, user2, user3]*/
        
        self.currentUser = createMockUser(
            name: "Ben Ten",
            lovedCuisines: ["Italian", "Japanese"],
            wantToTryCuisines: ["Thai", "Indian"],
            preferredDays: [5, 6], // Friday and Saturday
            availabilityStartTime: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)!,
            availabilityEndTime: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
        )
        
        var user1 = createMockUser(
            name: "Hate Mondays",
            lovedCuisines: ["French", "Thai"],
            wantToTryCuisines: ["Korean", "Mexican"],
            preferredDays: [3, 4, 5], // Wednesday, Thursday, Friday
            availabilityStartTime: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now)!,
            availabilityEndTime: calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        )
        
        var user2 = createMockUser(
            name: "WHAAAT",
            lovedCuisines: ["Mexican", "Indian"],
            wantToTryCuisines: ["Japanese", "Greek"],
            preferredDays: [4, 5, 6], // Thursday, Friday, Saturday
            availabilityStartTime: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)!,
            availabilityEndTime: calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)!
        )
        
        var user3 = createMockUser(
            name: "Harry Potter",
            lovedCuisines: ["Italian", "Greek"],
            wantToTryCuisines: ["Thai", "Vietnamese"],
            preferredDays: [2, 3, 4], // Tuesday, Wednesday, Thursday
            availabilityStartTime: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: now)!,
            availabilityEndTime: calendar.date(bySettingHour: 22, minute: 30, second: 0, of: now)!
        )
        
        // Set up friendships
        self.currentUser.friends = [user1, user2, user3]
        user1.friends = [self.currentUser, user2, user3]
        user2.friends = [self.currentUser, user1, user3]
        user3.friends = [self.currentUser, user1, user2]
        
        // Add users to the users array
        self.users = [self.currentUser, user1, user2, user3]
        
        
        
        requestCalendarAccess()
        fetchRestaurants()
        //updateGroupRecommendedOutings()
    }
    
    private func createMockUser(name: String, lovedCuisines: [String], wantToTryCuisines: [String], preferredDays: [Int], availabilityStartTime: Date, availabilityEndTime: Date) -> User {
        let calendar = Calendar.current
        let now = Date()
        
        var availableTimes: [AvailableTime] = []
        for day in 0...6 {
            if preferredDays.contains(day) {
                let date = calendar.date(byAdding: .day, value: (day - 1), to: now)!
                let startTime = calendar.date(bySettingHour: calendar.component(.hour, from: availabilityStartTime),
                                              minute: calendar.component(.minute, from: availabilityStartTime),
                                              second: 0,
                                              of: date)!
                let endTime = calendar.date(bySettingHour: calendar.component(.hour, from: availabilityEndTime),
                                            minute: calendar.component(.minute, from: availabilityEndTime),
                                            second: 0,
                                            of: date)!
                
                availableTimes.append(AvailableTime(date: date, startTime: startTime, endTime: endTime, weekday: day))
            }
        }
        
        return User(
            name: name,
            lovedCuisines: lovedCuisines,
            wantToTryCuisines: wantToTryCuisines,
            preferredDays: preferredDays,
            friends: [],
            availableTimes: availableTimes,
            availabilityStartTime: availabilityStartTime,
            availabilityEndTime: availabilityEndTime
        )
    }
    
    func updateGroupRecommendedOutings() {
        print("Updating group recommended outings...")
        
        let allUsers = [currentUser] + currentUser.friends
        let allPreferences = allUsers.flatMap { $0.lovedCuisines + $0.wantToTryCuisines }
        
        var potentialOutings: [(GroupRecommendedOuting, score: Double)] = []
        
        for restaurant in restaurants {
            if let bestTimeSlot = findBestGroupTimeSlot(for: allUsers, on: Date()) {
                print("Best Time Slot Found: \(bestTimeSlot.startTime) - \(bestTimeSlot.endTime)")
                let groupScore = calculateGroupScore(for: restaurant, users: allUsers, preferences: allPreferences, timeSlot: bestTimeSlot)
                let outing = GroupRecommendedOuting(restaurant: restaurant, participants: allUsers, bestTimeSlot: bestTimeSlot, groupScore: groupScore)
                potentialOutings.append((outing, groupScore))
            }
            else {
                print("No suitable time slot found for date:")
            }
        }
        
        potentialOutings.sort { $0.score > $1.score }
        groupRecommendedOutings = potentialOutings.prefix(20).map { $0.0 }
        
        print("Found \(groupRecommendedOutings.count) group recommended outings")
    }
    
    func findBestGroupTimeSlot(for users: [User], on date: Date, minDuration: TimeInterval = 3600, maxDuration: TimeInterval = 14400) -> (startTime: Date, endTime: Date)? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        let interval: TimeInterval = 5 * 60 // 5-minute intervals
        
        var availabilityScores: [Date: Int] = [:]
        var currentTime = dayStart
        
        // Initialize availability scores
        while currentTime < dayEnd {
            availabilityScores[currentTime] = 0
            currentTime = calendar.date(byAdding: .minute, value: 5, to: currentTime)!
        }
        
        // Assign scores based on user availability
        for user in users {
            for availableTime in user.availableTimes.filter({ calendar.isDate($0.date, inSameDayAs: date) }) {
                var slotTime = max(availableTime.startTime, dayStart)
                while slotTime < min(availableTime.endTime, dayEnd) {
                    availabilityScores[slotTime, default: 0] += 1
                    slotTime = calendar.date(byAdding: .minute, value: 5, to: slotTime)!
                }
            }
        }
        
        // Sort the slots by availability descending and time ascending
        let sortedSlots = availabilityScores.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
        
        // Iterate through durations to find the best slot
        for duration in stride(from: minDuration, through: maxDuration, by: interval) {
            for (startTime, score) in sortedSlots {
                let endTime = startTime.addingTimeInterval(duration)
                if endTime <= dayEnd {
                    let slotScores = stride(from: startTime, to: endTime, by: interval).map { availabilityScores[$0] ?? 0 }
                    let averageScore = Double(slotScores.reduce(0, +)) / Double(slotScores.count)
                    
                    if averageScore >= Double(users.count) * 0.5 {  // At least 50% availability
                        // Round startTime to nearest 30 minutes
                        let roundedStartTime = roundToNearestHalfHour(date: startTime)
                        let roundedEndTime = roundedStartTime.addingTimeInterval(duration)
                        return (startTime: roundedStartTime, endTime: roundedEndTime)
                    }
                }
            }
        }
        
        // If no slot meets the threshold, return the slot with highest availability
        if let bestSlot = sortedSlots.first {
            let startTime = bestSlot.key
            let endTime = startTime.addingTimeInterval(minDuration)
            return (startTime: roundToNearestHalfHour(date: startTime), endTime: roundToNearestHalfHour(date: endTime))
        }
        
        return nil
    }
    
    
    
    func calculateGroupScore(for restaurant: Restaurant, users: [User], preferences: [String], timeSlot: (startTime: Date, endTime: Date)) -> Double {
        let availabilityScore = calculateGroupAvailabilityScore(for: users, timeSlot: timeSlot)
        let preferenceScore = calculateGroupPreferenceScore(for: restaurant, preferences: preferences)
        let ratingScore = Double(restaurant.rating) / 5.0
        let priceScore = calculatePriceScore(for: restaurant)
        
        return (availabilityScore * 0.35) + (preferenceScore * 0.30) + (ratingScore * 0.20) + (priceScore * 0.15)
    }
    
    func calculateGroupAvailabilityScore(for users: [User], timeSlot: (startTime: Date, endTime: Date)) -> Double {
        let availableUsers = users.filter { user in
            user.availableTimes.contains { availableTime in
                availableTime.startTime <= timeSlot.startTime && availableTime.endTime >= timeSlot.endTime
            }
        }
        return Double(availableUsers.count) / Double(users.count)
    }
    
    func calculateGroupPreferenceScore(for restaurant: Restaurant, preferences: [String]) -> Double {
        let matchingPreferences = Set(restaurant.categories.map { $0.title }).intersection(Set(preferences))
        return Double(matchingPreferences.count) / Double(preferences.count)
    }
    
    func sendGroupInvitation(outing: GroupRecommendedOuting, startTime: Date, endTime: Date, enableForwarding: Bool, includeRandos: Bool) {
        let invitation = Invitation(
            from: currentUser,
            to: outing.participants.filter { $0.id != currentUser.id },
            restaurant: outing.restaurant,
            proposedStartTime: startTime,
            proposedEndTime: endTime,
            enableForwarding: enableForwarding,
            includeRandos: includeRandos,
            participants: outing.participants.map { Participant(user: $0, response: $0.id == currentUser.id ? .accepted : .pending) }
        )
        
        sentInvitations.append(invitation)
        upcomingEvents.append(invitation)
        
        for recipient in outing.participants where recipient.id != currentUser.id {
            if let index = users.firstIndex(where: { $0.id == recipient.id }) {
                users[index].receivedInvitations.append(invitation)
            }
        }
        
        promptToAddToCalendar(invitation: invitation)
    }
    func calculatePriceScore(for restaurant: Restaurant) -> Double {
        guard let price = restaurant.price else { return 0.5 } // Middle score if price is unknown
        switch price.count {
        case 1: return 1.0  // $ (least expensive)
        case 2: return 0.75 // $$
        case 3: return 0.5  // $$$
        case 4: return 0.25 // $$$$ (most expensive)
        default: return 0.5
        }
    }
    
    
    
    
    
    func findBestCommonTimeSlot(for users: [User], minimumDuration: TimeInterval = 7200) -> Date? {
        // Collect current user's available times
        let creatorTimes = currentUser.availableTimes
        
        for creatorTime in creatorTimes {
            var overlappingTime = creatorTime
            var allAvailable = true
            
            for user in users where user.id != currentUser.id {
                if let userTime = user.availableTimes.first(where: { Calendar.current.isDate($0.date, inSameDayAs: overlappingTime.date) }) {
                    let latestStart = max(overlappingTime.startTime, userTime.startTime)
                    let earliestEnd = min(overlappingTime.endTime, userTime.endTime)
                    if earliestEnd.timeIntervalSince(latestStart) >= minimumDuration {
                        overlappingTime.startTime = latestStart
                        overlappingTime.endTime = earliestEnd
                    } else {
                        allAvailable = false
                        break
                    }
                } else {
                    allAvailable = false
                    break
                }
            }
            
            if allAvailable {
                // Return the earliest overlapping time found
                return overlappingTime.startTime
            }
        }
        
        // No common time found
        return nil
    }
    
    
    
    
    func findBestTimeSlot(for users: [User], on date: Date, minDuration: TimeInterval = 7200, maxDuration: TimeInterval = 14400) -> (startTime: Date, endTime: Date)? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        let interval: TimeInterval = 5 * 60 // 5-minute intervals
        
        var availabilityScores: [Date: Double] = [:]
        var currentTime = dayStart
        
        // Initialize availability scores
        while currentTime < dayEnd {
            availabilityScores[currentTime] = 0
            currentTime = calendar.date(byAdding: .minute, value: 5, to: currentTime)!
        }
        
        // Assign scores based on user availability
        for user in users {
            for availableTime in user.availableTimes.filter({ calendar.isDate($0.date, inSameDayAs: date) }) {
                var slotTime = max(availableTime.startTime, dayStart)
                while slotTime < min(availableTime.endTime, dayEnd) {
                    availabilityScores[slotTime, default: 0] += 1
                    slotTime = calendar.date(byAdding: .minute, value: 5, to: slotTime)!
                }
            }
        }
        
        // Sort the slots by availability descending and time ascending
        let sortedSlots = availabilityScores.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
        
        // Iterate through durations to find the best slot
        for duration in stride(from: minDuration, through: maxDuration, by: interval) {
            for (startTime, _) in sortedSlots {
                let endTime = startTime.addingTimeInterval(duration)
                if endTime <= dayEnd {
                    let slotScores = stride(from: startTime, to: endTime, by: interval).map { availabilityScores[$0] ?? 0 }
                    let averageScore = slotScores.reduce(0, +) / Double(slotScores.count)
                    
                    if averageScore >= Double(users.count) * 0.75 {  // At least 75% availability
                        // Round startTime to nearest 30 minutes
                        let roundedStartTime = roundToNearestHalfHour(date: startTime)
                        let roundedEndTime = roundedStartTime.addingTimeInterval(duration)
                        return (startTime: roundedStartTime, endTime: roundedEndTime)
                    }
                }
            }
        }
        
        // If no slot meets the threshold, return the slot with highest availability
        if let bestSlot = sortedSlots.first {
            let startTime = bestSlot.key
            let endTime = startTime.addingTimeInterval(minDuration)
            return (startTime: roundToNearestHalfHour(date: startTime), endTime: roundToNearestHalfHour(date: endTime))
        }
        
        return nil
    }
    
    func roundToNearestHalfHour(date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        var roundedComponents = components
        
        if let minute = components.minute {
            if minute < 15 {
                roundedComponents.minute = 0
            } else if minute < 45 {
                roundedComponents.minute = 30
            } else {
                roundedComponents.hour = (components.hour ?? 0) + 1
                roundedComponents.minute = 0
            }
        }
        
        return calendar.date(from: roundedComponents) ?? date
    }
    
    
    
    
    func requestCalendarAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            if granted {
                self?.fetchCalendarEvents()
            } else {
                print("Calendar access denied.")
            }
        }
    }
    
    func fetchCalendarEvents() {
        print("Fetching calendar events...")
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let sevenDaysLater = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        let predicate = eventStore.predicateForEvents(withStart: now, end: sevenDaysLater, calendars: calendars)
        
        let events = eventStore.events(matching: predicate)
        print("Found \(events.count) events in the next 7 days")
        
        DispatchQueue.main.async { [weak self] in
            self?.currentUser.availableTimes = self?.generateAvailableTimes(from: events) ?? []
            print("Generated \(self?.currentUser.availableTimes.count ?? 0) available time slots")
            self?.updateRecommendedOutings()
        }
    }
    
    
    func generateAvailableTimes(from events: [EKEvent]) -> [AvailableTime] {
        var availableTimes: [AvailableTime] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Generate times for the next 7 days
        for dayOffset in 0...6 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: now)!
            let weekday = calendar.component(.weekday, from: date) - 1 // 0-6, where 0 is Sunday
            
            // Check if the day is in preferredDays
            if !currentUser.preferredDays.contains(weekday) {
                continue
            }
            
            let startOfEvening = calendar.date(bySettingHour: calendar.component(.hour, from: currentUser.availabilityStartTime),
                                               minute: calendar.component(.minute, from: currentUser.availabilityStartTime),
                                               second: 0,
                                               of: date)!
            
            var endOfEvening = calendar.date(bySettingHour: calendar.component(.hour, from: currentUser.availabilityEndTime),
                                             minute: calendar.component(.minute, from: currentUser.availabilityEndTime),
                                             second: 0,
                                             of: date)!
            
            if endOfEvening <= startOfEvening {
                // If end time is on the next day, add 24 hours
                endOfEvening = calendar.date(byAdding: .day, value: 1, to: endOfEvening)!
            }
            
            // Filter events for this day
            let dayEvents = events.filter { event in
                calendar.isDate(event.startDate, inSameDayAs: date) ||
                calendar.isDate(event.endDate, inSameDayAs: date)
            }
            
            var availableStart = startOfEvening
            for event in dayEvents.sorted(by: { $0.startDate < $1.startDate }) {
                if event.startDate > availableStart && event.startDate < endOfEvening {
                    // There's an available slot before this event
                    availableTimes.append(AvailableTime(date: date, startTime: availableStart, endTime: event.startDate, weekday: weekday))
                }
                // Move the available start time to after this event
                availableStart = max(availableStart, event.endDate)
            }
            
            // Check if there's available time after the last event
            if availableStart < endOfEvening {
                availableTimes.append(AvailableTime(date: date, startTime: availableStart, endTime: endOfEvening, weekday: weekday))
            }
        }
        
        return availableTimes
    }
    
    func fetchRestaurants() {
     let apiKey = "tuhu5KX82xiVBfNPwQeC0n-vesx7mDDo1OJul7PPmqsrDMrigjc2eDMp0CSamwUkUricjlrRooufMt8UpBMjGHiEN1d22708MvVnFCd99ClkkRCkl185umQwX28LZ3Yx"
     let encodedLocation = selectedLocation.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
     let url = URL(string: "https://api.yelp.com/v3/businesses/search?location=\(encodedLocation)&term=restaurants")!
     
     var request = URLRequest(url: url)
     request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
     
     print("Fetching restaurants from URL: \(url.absoluteString)")
     
     URLSession.shared.dataTask(with: request) { data, response, error in
     if let error = error {
     print("Request Error: \(error)")
     return
     }
     
     if let httpResponse = response as? HTTPURLResponse {
     print("HTTP Response Status Code: \(httpResponse.statusCode)")
     }
     
     if let data = data {
     print("Received data of size: \(data.count) bytes")
     
     // Print the raw JSON as a string
     if let jsonString = String(data: data, encoding: .utf8) {
     print("Raw JSON response:")
     print(jsonString)
     }
     
     do {
     let decodedResponse = try JSONDecoder().decode(YelpResponse.self, from: data)
     print("Successfully decoded YelpResponse")
     print("Number of businesses received: \(decodedResponse.businesses.count)")
     
     DispatchQueue.main.async {
     self.restaurants = decodedResponse.businesses
     print("Updated restaurants array with \(self.restaurants.count) items")
     
     // Print details of the first few restaurants
     for (index, restaurant) in self.restaurants.enumerated() {
     print("Restaurant \(index + 1):")
     print("  Name: \(restaurant.name)")
     print("  Rating: \(restaurant.rating)")
     print("  Categories: \(restaurant.categories.map { $0.title }.joined(separator: ", "))")
     if let businessHours = restaurant.businessHours?.first {
     print("  Open Hours: \(businessHours.open.map { "Day \($0.day): \($0.start)-\($0.end)" }.joined(separator: ", "))")
     print("  Is Open Now: \(businessHours.isOpenNow)")
     } else {
     print("  Open Hours: Not available")
     }
     }
     
     // After updating restaurants, call updateRecommendedOutings
     self.updateRecommendedOutings()
         self.updateGroupRecommendedOutings()
     }
     } catch {
     print("Error decoding JSON: \(error)")
     if let decodingError = error as? DecodingError {
     switch decodingError {
     case .dataCorrupted(let context):
     print("Data corrupted: \(context)")
     case .keyNotFound(let key, let context):
     print("Key not found: \(key), context: \(context)")
     case .typeMismatch(let type, let context):
     print("Type mismatch: expected \(type), context: \(context)")
     case .valueNotFound(let type, let context):
     print("Value not found: expected \(type), context: \(context)")
     @unknown default:
     print("Unknown decoding error")
     }
     }
     }
     }
     }.resume()
     }
     
    
    /*func fetchRestaurants() {
        // For testing purposes, we'll create mock restaurants instead of fetching from an API
        let mockRestaurants = [
            createMockRestaurant(name: "Pasta Paradise", cuisine: "Italian", rating: 4.5, price: "$$"),
            createMockRestaurant(name: "Sushi Supreme", cuisine: "Japanese", rating: 4.7, price: "$$$"),
            createMockRestaurant(name: "Taco Town", cuisine: "Mexican", rating: 4.2, price: "$"),
            createMockRestaurant(name: "Thai Delight", cuisine: "Thai", rating: 4.4, price: "$$"),
            createMockRestaurant(name: "India House", cuisine: "Indian", rating: 4.6, price: "$$"),
            createMockRestaurant(name: "Greek Taverna", cuisine: "Greek", rating: 4.3, price: "$$"),
            createMockRestaurant(name: "French Bistro", cuisine: "French", rating: 4.8, price: "$$$"),
            createMockRestaurant(name: "Korean BBQ", cuisine: "Korean", rating: 4.5, price: "$$$"),
            createMockRestaurant(name: "Pho Palace", cuisine: "Vietnamese", rating: 4.1, price: "$")
        ]
        
        self.restaurants = mockRestaurants
        print("Loaded \(mockRestaurants.count) mock restaurants")
        
        updateRecommendedOutings()
        updateGroupRecommendedOutings()
    }
    
    private func createMockRestaurant(name: String, cuisine: String, rating: Double, price: String) -> Restaurant {
        let id = UUID().uuidString
        return Restaurant(
            id: id,
            name: name,
            rating: rating,
            location: Location(address1: "123 Main St", city: self.selectedLocation, displayAddress: ["123 Main St", self.selectedLocation]),
            imageUrl: "https://example.com/\(id).jpg",
            reviewCount: Int.random(in: 50...500),
            price: price,
            categories: [Category(title: cuisine)],
            phone: "+1234567890",
            url: "https://example.com/\(id)",
            isClosed: false,
            businessHours: [
                BusinessHours(
                    open: [
                        OpenHours(start: "1100", end: "2200", day: 0, isOvernight: false),
                        OpenHours(start: "1100", end: "2200", day: 1, isOvernight: false),
                        OpenHours(start: "1100", end: "2200", day: 2, isOvernight: false),
                        OpenHours(start: "1100", end: "2200", day: 3, isOvernight: false),
                        OpenHours(start: "1100", end: "2300", day: 4, isOvernight: false),
                        OpenHours(start: "1100", end: "2300", day: 5, isOvernight: false),
                        OpenHours(start: "1100", end: "2300", day: 6, isOvernight: false)
                    ],
                    hoursType: "REGULAR",
                    isOpenNow: true
                )
            ]
        )
    }*/
    
    
    func updateRecommendedOutings() {
        print("Updating recommended outings...")
        print("Total restaurants: \(restaurants.count)")
        print("User preferences: \(currentUser.lovedCuisines + currentUser.wantToTryCuisines)")
        print("User available times: \(currentUser.availableTimes)")
        
        // Clear previous recommendations
        recommendedOutings.removeAll()
        
        for availableTime in currentUser.availableTimes {
            let dayRecommendations = restaurants.filter { restaurant in
                guard let businessHours = restaurant.businessHours?.first else {
                    print("No business hours for \(restaurant.name)")
                    return false
                }
                
                let openHours = businessHours.open
                
                let isAvailable = openHours.contains { openHour in
                    // Convert openHour.start and openHour.end to minutes since midnight
                    let restaurantStartMinutes = (Int(openHour.start.prefix(2)) ?? 0) * 60 + (Int(openHour.start.suffix(2)) ?? 0)
                    var restaurantEndMinutes = (Int(openHour.end.prefix(2)) ?? 0) * 60 + (Int(openHour.end.suffix(2)) ?? 0)
                    
                    if restaurantEndMinutes <= restaurantStartMinutes {
                        restaurantEndMinutes += 24 * 60 // Adjust for overnight or midnight closing
                    }
                    
                    // Similarly, compute user start and end minutes since midnight
                    let userStartMinutes = Calendar.current.component(.hour, from: availableTime.startTime) * 60 + Calendar.current.component(.minute, from: availableTime.startTime)
                    var userEndMinutes = Calendar.current.component(.hour, from: availableTime.endTime) * 60 + Calendar.current.component(.minute, from: availableTime.endTime)
                    
                    if userEndMinutes <= userStartMinutes {
                        userEndMinutes += 24 * 60 // Adjust for overnight availability
                    }
                    
                    // Check if days match
                    let restaurantDay = openHour.day
                    let userDay = availableTime.weekday
                    
                    if restaurantDay != userDay {
                        return false
                    }
                    
                    // Check if time intervals overlap
                    let latestStart = max(restaurantStartMinutes, userStartMinutes)
                    let earliestEnd = min(restaurantEndMinutes, userEndMinutes)
                    
                    return latestStart < earliestEnd
                }
                
                let userPreferences = currentUser.lovedCuisines + currentUser.wantToTryCuisines
                
                let matchesPreferences = restaurant.categories.contains { category in
                    userPreferences.contains(category.title)
                }
                
                return isAvailable && matchesPreferences
            }
            
            // For each recommended restaurant, create a struct that includes the date
            let outingsForDay = dayRecommendations.map { restaurant in
                RecommendedOuting(restaurant: restaurant, date: availableTime.date)
            }
            
            // Append to recommendedOutings
            recommendedOutings.append(contentsOf: outingsForDay)
        }
        
        print("Found \(recommendedOutings.count) recommended outings")
    }
    
    
    
    func sendInvitation(to friends: [User], for restaurant: Restaurant, at startTime: Date, endTime: Date, enableForwarding: Bool, includeRandos: Bool) {
        var finalRecipients = friends
        
        if includeRandos {
            let potentialRandos = users.filter { user in
                !user.friends.contains(where: { $0.id == currentUser.id }) &&
                user.id != currentUser.id &&
                !currentUser.friends.contains(where: { $0.id == user.id })
            }
            if let randomUser = potentialRandos.randomElement() {
                finalRecipients.append(randomUser)
            }
        }
        
        // Include the inviter and set their response to .accepted
        let participants = ([currentUser] + finalRecipients).map { Participant(user: $0, response: $0.id == currentUser.id ? .accepted : .pending) }
        
        let invitation = Invitation(
            from: currentUser,
            to: finalRecipients,
            restaurant: restaurant,
            proposedStartTime: startTime,
            proposedEndTime: endTime,
            enableForwarding: enableForwarding,
            includeRandos: includeRandos,
            participants: participants
        )
        
        sentInvitations.append(invitation)
        upcomingEvents.append(invitation)
        
        for recipient in finalRecipients {
            if let index = users.firstIndex(where: { $0.id == recipient.id }) {
                users[index].receivedInvitations.append(invitation)
            }
        }
        
        // Prompt to add to calendar for the current user
        promptToAddToCalendar(invitation: invitation)
    }
    
    func promptToAddToCalendar(invitation: Invitation) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Add to Calendar", message: "Do you want to add this event to your calendar?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
                self.addEventToCalendar(invitation: invitation)
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            
            // Present the alert from the root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    
    func respondToInvitation(_ invitation: Invitation, user: User, accept: Bool) {
        // Update the invitation in receivedInvitations
        if let userIndex = users.firstIndex(where: { $0.id == user.id }) {
            if let invitationIndex = users[userIndex].receivedInvitations.firstIndex(where: { $0.id == invitation.id }) {
                if let participantIndex = users[userIndex].receivedInvitations[invitationIndex].participants.firstIndex(where: { $0.user.id == user.id }) {
                    users[userIndex].receivedInvitations[invitationIndex].participants[participantIndex].response = accept ? .accepted : .declined
                    
                    if accept {
                        // Add to upcoming events
                        upcomingEvents.append(users[userIndex].receivedInvitations[invitationIndex])
                        // Add event to calendar
                        addEventToCalendar(invitation: users[userIndex].receivedInvitations[invitationIndex])
                    }
                    
                    // Optionally, remove the invitation if all participants have responded
                    let allResponded = users[userIndex].receivedInvitations[invitationIndex].participants.allSatisfy { $0.response != .pending }
                    if allResponded {
                        users[userIndex].receivedInvitations.remove(at: invitationIndex)
                    }
                }
            }
        }
        
        // Update the invitation in sentInvitations
        if let senderIndex = users.firstIndex(where: { $0.id == invitation.from.id }) {
            if let sentInvitationIndex = users[senderIndex].sentInvitations.firstIndex(where: { $0.id == invitation.id }) {
                if let participantIndex = users[senderIndex].sentInvitations[sentInvitationIndex].participants.firstIndex(where: { $0.user.id == user.id }) {
                    users[senderIndex].sentInvitations[sentInvitationIndex].participants[participantIndex].response = accept ? .accepted : .declined
                }
            }
        }
    }
    
    
    func forwardInvitation(_ invitation: Invitation, to newFriends: [User]) {
        var updatedInvitation = invitation
        updatedInvitation.to.append(contentsOf: newFriends)
        updatedInvitation.participants.append(contentsOf: newFriends.map { Participant(user: $0, response: .pending) })
        
        // Update sentInvitations
        if let senderIndex = users.firstIndex(where: { $0.id == invitation.from.id }) {
            if let sentInvitationIndex = users[senderIndex].sentInvitations.firstIndex(where: { $0.id == invitation.id }) {
                users[senderIndex].sentInvitations[sentInvitationIndex] = updatedInvitation
            }
        }
        
        // Add the forwarded invitation to new friends' receivedInvitations
        for friend in newFriends {
            if let index = users.firstIndex(where: { $0.id == friend.id }) {
                users[index].receivedInvitations.append(updatedInvitation)
            }
        }
    }
    
    
    func addEventToCalendar(invitation: Invitation) {
        // Ensure there's a default calendar available
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            print("No default calendar available.")
            return
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "Outing to \(invitation.restaurant.name)"
        event.startDate = invitation.proposedStartTime
        event.endDate = invitation.proposedEndTime
        event.notes = "Meeting friends at \(invitation.restaurant.name)"
        event.calendar = calendar // Assign the calendar
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("Event added to calendar")
        } catch {
            print("Failed to add event to calendar: \(error)")
        }
    }
    
}


// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            AutoPlanView()
                .tabItem {
                    Label("Auto Plan", systemImage: "calendar.badge.clock")
                }
            
            
            InvitationsView()
                .tabItem {
                    Label("Invitations", systemImage: "envelope")
                }
            
            UpcomingEventsView()
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .environmentObject(viewModel)
    }
}


struct AutoPlanView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Location Dropdown
                Picker("Location", selection: $viewModel.selectedLocation) {
                    ForEach(viewModel.locations, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color.blue.opacity(0.1))
                
                // Group Top Picks Header
                Text("Group Top Picks")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.clear]), startPoint: .top, endPoint: .bottom)
                    )
                
                // Group Restaurant Cards
                GeometryReader { geometry in
                    TabView {
                        ForEach(viewModel.groupRecommendedOutings) { outing in
                            GroupRestaurantCard(outing: outing)
                                .frame(width: geometry.size.width - 40, height: geometry.size.height - 100)
                                .padding(.bottom, 20)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct GroupRestaurantCard: View {
    let outing: GroupRecommendedOuting
    @EnvironmentObject var viewModel: ContentViewModel
    @State private var showingInviteSheet = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray.opacity(0.2)]), startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 10)
            
            VStack(alignment: .leading, spacing: 15) {
                // Restaurant Image
                AsyncImage(url: URL(string: outing.restaurant.imageUrl)) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Restaurant Name
                Text(outing.restaurant.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                // Rating and Reviews
                HStack {
                    ForEach(0..<Int(outing.restaurant.rating.rounded()), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    Text("(\(outing.restaurant.reviewCount) reviews)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Categories and Price
                HStack {
                    Text(outing.restaurant.categories.map { $0.title }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if let price = outing.restaurant.price {
                        Text(price)
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                // Address
                Text(outing.restaurant.location.displayAddress.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Open Now
                if let businessHours = outing.restaurant.businessHours?.first {
                    Text("Open Now: \(businessHours.isOpenNow ? "Yes" : "No")")
                        .font(.subheadline)
                        .foregroundColor(businessHours.isOpenNow ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(businessHours.isOpenNow ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Group Score
                Text("Group Score: \(String(format: "%.1f", outing.groupScore))")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button(action: {
                        showingInviteSheet = true
                    }) {
                        Text("Invite Group")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        if let url = URL(string: outing.restaurant.url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("View on Yelp")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingInviteSheet) {
            GroupInviteView(outing: outing)
        }
    }
}

struct GroupInviteView: View {
    let outing: GroupRecommendedOuting
    @EnvironmentObject var viewModel: ContentViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var proposedStartTime: Date
    @State private var proposedEndTime: Date
    @State private var enableForwarding = false
    @State private var includeRandos = false
    
    init(outing: GroupRecommendedOuting) {
        self.outing = outing
        _proposedStartTime = State(initialValue: outing.bestTimeSlot.startTime)
        _proposedEndTime = State(initialValue: outing.bestTimeSlot.endTime)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Proposed Time")) {
                    DatePicker("Start Time", selection: $proposedStartTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Time", selection: $proposedEndTime, displayedComponents: [.hourAndMinute])
                }
                
                Section(header: Text("Participants")) {
                    ForEach(outing.participants) { participant in
                        Text(participant.name)
                    }
                }
                
                Section {
                    Toggle("Enable Forwarding", isOn: $enableForwarding)
                    Toggle("Okay with Randos", isOn: $includeRandos)
                }
                
                Button("Send Invitation") {
                    viewModel.sendGroupInvitation(outing: outing, startTime: proposedStartTime, endTime: proposedEndTime, enableForwarding: enableForwarding, includeRandos: includeRandos)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationTitle("Invite Group")
        }
    }
}


struct HomeView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Location Dropdown
                Picker("Location", selection: $viewModel.selectedLocation) {
                    ForEach(viewModel.locations, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color.blue.opacity(0.1))
                
                // Top Picks Header
                Text("Our Top Picks")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.clear]), startPoint: .top, endPoint: .bottom)
                    )
                
                // Restaurant Cards
                GeometryReader { geometry in
                    TabView {
                        ForEach(viewModel.recommendedOutings) { outing in
                            RestaurantCard(outing: outing)
                                .frame(width: geometry.size.width - 40, height: geometry.size.height - 100)
                                .padding(.bottom, 20)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct RestaurantCard: View {
    let outing: RecommendedOuting
    @EnvironmentObject var viewModel: ContentViewModel
    @State private var showingInviteSheet = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray.opacity(0.2)]), startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 10)
            
            VStack(alignment: .leading, spacing: 15) {
                // Restaurant Image
                AsyncImage(url: URL(string: outing.restaurant.imageUrl)) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Restaurant Name
                Text(outing.restaurant.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                // Rating and Reviews
                HStack {
                    ForEach(0..<Int(outing.restaurant.rating.rounded()), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    Text("(\(outing.restaurant.reviewCount) reviews)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Categories and Price
                HStack {
                    Text(outing.restaurant.categories.map { $0.title }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if let price = outing.restaurant.price {
                        Text(price)
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                // Address
                Text(outing.restaurant.location.displayAddress.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Open Now
                if let businessHours = outing.restaurant.businessHours?.first {
                    Text("Open Now: \(businessHours.isOpenNow ? "Yes" : "No")")
                        .font(.subheadline)
                        .foregroundColor(businessHours.isOpenNow ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(businessHours.isOpenNow ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Outing Date
                Text("Date: \(outing.date, formatter: dateFormatter)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button(action: {
                        showingInviteSheet = true
                    }) {
                        Text("Invite Group")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        if let url = URL(string: outing.restaurant.url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("View on Yelp")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteView(outing: outing)
        }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }
}

struct InviteView: View {
    let outing: RecommendedOuting
    @EnvironmentObject var viewModel: ContentViewModel
    @State private var selectedFriends: Set<UUID> = []
    @State private var proposedStartTime: Date
    @State private var proposedEndTime: Date
    @State private var enableForwarding = false
    @State private var includeRandos = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showNoOverlapAlert = false
    @State private var overlapStatuses: [UUID: OverlapStatus] = [:]
    
    init(outing: RecommendedOuting) {
        self.outing = outing
        _proposedStartTime = State(initialValue: outing.date)
        _proposedEndTime = State(initialValue: outing.date.addingTimeInterval(7200)) // Default to 2 hours later
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Friends")) {
                    ForEach(viewModel.currentUser.friends) { friend in
                        MultipleSelectionRow(title: friend.name, isSelected: selectedFriends.contains(friend.id)) {
                            if selectedFriends.contains(friend.id) {
                                selectedFriends.remove(friend.id)
                            } else {
                                selectedFriends.insert(friend.id)
                            }
                            updateProposedTime() // Recalculate when selection changes
                        }
                    }
                }
                
                Section(header: Text("Proposed Time")) {
                    DatePicker("Start Time", selection: $proposedStartTime, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: proposedStartTime) { _ in
                            updateOverlapStatuses()
                        }
                    DatePicker("End Time", selection: $proposedEndTime, displayedComponents: [.hourAndMinute])
                        .onChange(of: proposedEndTime) { _ in
                            updateOverlapStatuses()
                        }
                }
                
                Section(header: Text("Friends' Availability")) {
                    ForEach(viewModel.currentUser.friends.filter { selectedFriends.contains($0.id) }) { friend in
                        if let availability = friend.availableTimes.first(where: { Calendar.current.isDate($0.date, inSameDayAs: proposedStartTime) }) {
                            let status = overlapStatuses[friend.id] ?? .none
                            
                            HStack {
                                Text("\(friend.name): \(formatTime(availability.startTime)) - \(formatTime(availability.endTime))")
                                    .foregroundColor(colorForStatus(status))
                                Spacer()
                                Image(systemName: iconForStatus(status))
                                    .foregroundColor(colorForStatus(status))
                            }
                        } else {
                            HStack {
                                Text("\(friend.name): No availability")
                                    .foregroundColor(.red)
                                Spacer()
                                Image(systemName: "xmark.octagon")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("Enable Forwarding", isOn: $enableForwarding)
                    Toggle("Okay with Randos", isOn: $includeRandos)
                }
                
                Button("Send Invitation") {
                    let invitedFriends = viewModel.users.filter { selectedFriends.contains($0.id) }
                    viewModel.sendInvitation(to: invitedFriends, for: outing.restaurant, at: proposedStartTime, endTime: proposedEndTime, enableForwarding: enableForwarding, includeRandos: includeRandos)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedFriends.isEmpty)
            }
            .navigationTitle("Invite Friends")
            .onAppear {
                updateProposedTime()
            }
            .onChange(of: selectedFriends) { _ in
                updateProposedTime()
            }
            .alert(isPresented: $showNoOverlapAlert) {
                Alert(
                    title: Text("No Overlapping Time"),
                    message: Text("Selected friends do not have overlapping availability for the proposed time."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Helper function to determine the color based on overlap status
    func colorForStatus(_ status: OverlapStatus) -> Color {
        switch status {
        case .full:
            return .green
        case .partial:
            return .yellow
        case .none:
            return .red
        }
    }
    
    // Helper function to determine the icon based on overlap status
    func iconForStatus(_ status: OverlapStatus) -> String {
        switch status {
        case .full:
            return "checkmark.circle"
        case .partial:
            return "exclamationmark.triangle"
        case .none:
            return "xmark.octagon"
        }
    }
    
    // Helper function to determine overlap status
    func getOverlapStatus(friendStart: Date, friendEnd: Date, inviteStart: Date, inviteEnd: Date) -> OverlapStatus {
        if friendStart <= inviteStart && friendEnd >= inviteEnd {
            return .full
        } else if friendEnd <= inviteStart || friendStart >= inviteEnd {
            return .none
        } else {
            return .partial
        }
    }
    
    func updateProposedTime() {
        let selectedUsers = [viewModel.currentUser] + viewModel.users.filter { selectedFriends.contains($0.id) }
        if let bestSlot = viewModel.findBestTimeSlot(for: selectedUsers, on: outing.date) {
            proposedStartTime = bestSlot.startTime
            proposedEndTime = bestSlot.endTime
            updateOverlapStatuses()
        } else {
            // Fallback to default or notify user
            proposedStartTime = outing.date
            proposedEndTime = outing.date.addingTimeInterval(7200)
            showNoOverlapAlert = true
            updateOverlapStatuses()
        }
    }
    func updateOverlapStatuses() {
        for friendId in selectedFriends {
            if let friend = viewModel.currentUser.friends.first(where: { $0.id == friendId }),
               let availability = friend.availableTimes.first(where: { Calendar.current.isDate($0.date, inSameDayAs: proposedStartTime) }) {
                let status = getOverlapStatus(
                    friendStart: availability.startTime,
                    friendEnd: availability.endTime,
                    inviteStart: proposedStartTime,
                    inviteEnd: proposedEndTime
                )
                overlapStatuses[friendId] = status
            } else {
                overlapStatuses[friendId] = .none
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}








struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: self.action) {
            HStack {
                Text(self.title)
                    .foregroundColor(.primary)
                Spacer()
                if self.isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
    }
}


struct InvitationsView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Received Invitations")) {
                    ForEach(viewModel.receivedInvitations) { invitation in
                        ReceivedInvitationRow(invitation: invitation)
                    }
                }
                
                Section(header: Text("Sent Invitations")) {
                    ForEach(viewModel.sentInvitations) { invitation in
                        SentInvitationRow(invitation: invitation)
                    }
                }
            }
            .navigationTitle("Invitations")
        }
    }
}

struct ReceivedInvitationRow: View {
    let invitation: Invitation
    @EnvironmentObject var viewModel: ContentViewModel
    @State private var showingForwardView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(invitation.from.name) invited you to \(invitation.restaurant.name)")
                .font(.headline)
            Text("Time: \(formatDateTime(invitation.proposedStartTime)) - \(formatTime(invitation.proposedEndTime))")
            
            DisclosureGroup("Participants (\(invitation.participants.count))") {
                ForEach(invitation.participants) { participant in
                    HStack {
                        Text(participant.user.name)
                        Spacer()
                        Text(participant.response.rawValue)
                            .foregroundColor(colorForStatus(participant.response))
                    }
                }
            }
            
            HStack {
                Button("Accept") {
                    viewModel.respondToInvitation(invitation, user: viewModel.currentUser, accept: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button("Decline") {
                    viewModel.respondToInvitation(invitation, user: viewModel.currentUser, accept: false)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                if invitation.enableForwarding {
                    Button("Forward") {
                        showingForwardView = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .sheet(isPresented: $showingForwardView) {
            ForwardInvitationView(invitation: invitation)
        }
    }
    
    func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func colorForStatus(_ status: InvitationStatus) -> Color {
        switch status {
        case .accepted: return .green
        case .declined: return .red
        case .pending: return .orange
        }
    }
}

struct SentInvitationRow: View {
    let invitation: Invitation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(invitation.restaurant.name)")
                .font(.headline)
            Text("Time: \(formatDateTime(invitation.proposedStartTime)) - \(formatTime(invitation.proposedEndTime))")
            
            DisclosureGroup("Participants (\(invitation.participants.count))") {
                ForEach(invitation.participants) { participant in
                    HStack {
                        Text(participant.user.name)
                        Spacer()
                        Text(participant.response.rawValue)
                            .foregroundColor(colorForStatus(participant.response))
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func colorForStatus(_ status: InvitationStatus) -> Color {
        switch status {
        case .accepted: return .green
        case .declined: return .red
        case .pending: return .orange
        }
    }
}

struct InvitationRow: View {
    let invitation: Invitation
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(invitation.from.name) invited you to \(invitation.restaurant.name)")
                .font(.headline)
            Text("Time: \(formatDate(invitation.proposedStartTime)) - \(formatTime(invitation.proposedEndTime))")
            Text("Participants: \(invitation.participants.count)")
            
            DisclosureGroup("Responses") {
                ForEach(invitation.participants) { participant in
                    HStack {
                        Text(participant.user.name)
                        Spacer()
                        Text(participant.response.rawValue.capitalized)
                            .foregroundColor(colorForStatus(participant.response))
                    }
                }
            }
            
            HStack {
                Button("Accept") {
                    viewModel.respondToInvitation(invitation, user: viewModel.currentUser, accept: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button("Decline") {
                    viewModel.respondToInvitation(invitation, user: viewModel.currentUser, accept: false)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                if invitation.enableForwarding {
                    Button("Forward") {
                        // Present ForwardInvitationView
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func colorForStatus(_ status: InvitationStatus) -> Color {
        switch status {
        case .accepted: return .green
        case .declined: return .red
        case .pending: return .orange
        }
    }
}


struct ProfileView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    @State private var showingPreferences = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                        
                        Text(viewModel.currentUser.name)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                    
                    // Cuisine Preferences
                    PreferenceSection(title: "Favorite Cuisines", cuisines: viewModel.currentUser.lovedCuisines)
                    PreferenceSection(title: "Want to Try", cuisines: viewModel.currentUser.wantToTryCuisines)
                    
                    // Preferred Days
                    VStack(alignment: .leading) {
                        Text("Preferred Days")
                            .font(.headline)
                        
                        HStack {
                            ForEach(0..<7) { day in
                                VStack {
                                    Text(dayAbbreviation(for: day))
                                        .font(.caption)
                                    Circle()
                                        .fill(viewModel.currentUser.preferredDays.contains(day) ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            togglePreferredDay(day)
                                        }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(20)
                    
                    // Availability Time Range
                    VStack(alignment: .leading) {
                        Text("Availability Time Range")
                            .font(.headline)
                        
                        HStack {
                            DatePicker("Start Time", selection: $viewModel.currentUser.availabilityStartTime, displayedComponents: .hourAndMinute)
                            DatePicker("End Time", selection: $viewModel.currentUser.availabilityEndTime, displayedComponents: .hourAndMinute)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(20)
                    
                    // Available Times from Calendar
                    VStack(alignment: .leading) {
                        Text("Available Times")
                            .font(.headline)
                        
                        ForEach(viewModel.currentUser.availableTimes) { time in
                            HStack {
                                Text("\(dayName(for: time.weekday))")
                                Spacer()
                                Text("\(formatTime(time.startTime)) - \(formatTime(time.endTime))")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(20)
                    
                    // Friends
                    VStack(alignment: .leading) {
                        Text("Friends")
                            .font(.headline)
                        
                        ForEach(viewModel.currentUser.friends) { friend in
                            Text(friend.name)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(20)
                    
                    // Edit Preferences Button
                    Button(action: {
                        showingPreferences = true
                    }) {
                        Text("Edit Preferences")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingPreferences) {
                PreferencesView()
            }
        }
        .onChange(of: viewModel.currentUser.availabilityStartTime) { _ in
            viewModel.fetchCalendarEvents()
        }
        .onChange(of: viewModel.currentUser.availabilityEndTime) { _ in
            viewModel.fetchCalendarEvents()
        }
    }
    
    func dayAbbreviation(for day: Int) -> String {
        let days = ["S", "M", "T", "W", "T", "F", "S"]
        return days[day]
    }
    
    func dayName(for weekday: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[weekday]
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func togglePreferredDay(_ day: Int) {
        if viewModel.currentUser.preferredDays.contains(day) {
            viewModel.currentUser.preferredDays.removeAll { $0 == day }
        } else {
            viewModel.currentUser.preferredDays.append(day)
        }
        viewModel.fetchCalendarEvents()
    }
}


struct PreferenceSection: View {
    let title: String
    let cuisines: [String]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(cuisines, id: \.self) { cuisine in
                    Text(cuisine)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(20)
    }
}



struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, proposal: proposal).offsets
        
        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }
    
    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        guard let containerWidth = proposal.width else { return ([], .zero) }
        
        var result: [CGPoint] = []
        var currentPosition: CGPoint = .zero
        var lineHeight: CGFloat = 0
        
        for size in sizes {
            if currentPosition.x + size.width > containerWidth {
                currentPosition.x = 0
                currentPosition.y += lineHeight + spacing
                lineHeight = 0
            }
            
            result.append(currentPosition)
            currentPosition.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        return (result, CGSize(width: containerWidth, height: currentPosition.y + lineHeight))
    }
}

struct PreferencesView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var lovedCuisines: Set<String> = []
    @State private var wantToTryCuisines: Set<String> = []
    
    let cuisines = [
        "Italian", "Japanese", "Chinese", "Mexican", "French", "Thai", "Indian", "Greek",
        "Mediterranean", "Spanish", "Vietnamese", "Korean", "American", "Lebanese",
        "Turkish", "German", "Caribbean", "Brazilian", "Ethiopian", "Moroccan"
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("I LOVE")) {
                    ForEach(cuisines, id: \.self) { cuisine in
                        MultipleSelectionRow(title: cuisine, isSelected: lovedCuisines.contains(cuisine)) {
                            if lovedCuisines.contains(cuisine) {
                                lovedCuisines.remove(cuisine)
                            } else {
                                lovedCuisines.insert(cuisine)
                                wantToTryCuisines.remove(cuisine) // Ensure no duplicates
                            }
                        }
                    }
                }
                
                Section(header: Text("I have never had")) {
                    ForEach(cuisines, id: \.self) { cuisine in
                        MultipleSelectionRow(title: cuisine, isSelected: wantToTryCuisines.contains(cuisine)) {
                            if wantToTryCuisines.contains(cuisine) {
                                wantToTryCuisines.remove(cuisine)
                            } else {
                                wantToTryCuisines.insert(cuisine)
                                lovedCuisines.remove(cuisine) // Ensure no duplicates
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Cuisines")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Save the selections to currentUser
                        viewModel.currentUser.lovedCuisines = Array(lovedCuisines)
                        viewModel.currentUser.wantToTryCuisines = Array(wantToTryCuisines)
                        // Update recommendations
                        viewModel.updateRecommendedOutings()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                lovedCuisines = Set(viewModel.currentUser.lovedCuisines)
                wantToTryCuisines = Set(viewModel.currentUser.wantToTryCuisines)
            }
        }
    }
}
struct UpcomingEventsView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.upcomingEvents) { event in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.restaurant.name)
                            .font(.headline)
                        Text("Date: \(event.proposedStartTime, formatter: dateFormatter) - \(event.proposedEndTime, formatter: timeFormatter)")
                        
                        DisclosureGroup("Participants (\(event.participants.count))") {
                            ForEach(event.participants) { participant in
                                HStack {
                                    Text(participant.user.name)
                                    Spacer()
                                    Text(participant.response.rawValue)
                                        .foregroundColor(colorForStatus(participant.response))
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Upcoming Events")
        }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
    
    func colorForStatus(_ status: InvitationStatus) -> Color {
        switch status {
        case .accepted: return .green
        case .declined: return .red
        case .pending: return .orange
        }
    }
}
struct ForwardInvitationView: View {
    let invitation: Invitation
    @EnvironmentObject var viewModel: ContentViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedFriends: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Friends to Forward To")) {
                    ForEach(viewModel.currentUser.friends.filter { friend in
                        !invitation.to.contains(where: { $0.id == friend.id })
                    }) { friend in
                        MultipleSelectionRow(title: friend.name, isSelected: selectedFriends.contains(friend.id)) {
                            if selectedFriends.contains(friend.id) {
                                selectedFriends.remove(friend.id)
                            } else {
                                selectedFriends.insert(friend.id)
                            }
                        }
                    }
                }
                
                Button("Forward Invitation") {
                    let friendsToForward = viewModel.currentUser.friends.filter { selectedFriends.contains($0.id) }
                    viewModel.forwardInvitation(invitation, to: friendsToForward)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedFriends.isEmpty)
            }
            .navigationTitle("Forward Invitation")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
