import SwiftUI
import EventKit
import Foundation

// MARK: - Models
struct User: Identifiable {
    let id = UUID()
    var name: String
    var preferences: [String]
    var friends: [User]
    var availableTimes: [AvailableTime]
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
    let to: [User]
    let restaurant: Restaurant
    let proposedTime: Date
    var status: InvitationStatus = .pending
}

enum InvitationStatus {
    case pending, accepted, declined
}

// MARK: - ViewModel
class ContentViewModel: ObservableObject {
    @Published var currentUser: User
    @Published var restaurants: [Restaurant] = []
    @Published var recommendedOutings: [Restaurant] = []
    @Published var sentInvitations: [Invitation] = []
    @Published var receivedInvitations: [Invitation] = []
    
    let eventStore = EKEventStore()
    
    init() {
        // Mock user data
        self.currentUser = User(
            name: "John Doe",
            preferences: ["Italian", "Japanese"],
            friends: [
                User(name: "Jane Smith", preferences: ["Mexican", "Italian"], friends: [], availableTimes: []),
                User(name: "Bob Johnson", preferences: ["Chinese", "Japanese"], friends: [], availableTimes: [])
            ],
            availableTimes: []
        )
        
        requestCalendarAccess()
        fetchRestaurants()
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
            
            let startOfEvening = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date)!
            let endOfEvening = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date.addingTimeInterval(86400))!
            
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
        let url = URL(string: "https://api.yelp.com/v3/businesses/search?location=New+York&term=restaurants&open_now=true")!
        
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
    
    func updateRecommendedOutings() {
        print("Updating recommended outings...")
        print("Total restaurants: \(restaurants.count)")
        print("User preferences: \(currentUser.preferences)")
        print("User available times: \(currentUser.availableTimes)")

        recommendedOutings = restaurants.filter { restaurant in
            guard let businessHours = restaurant.businessHours?.first else {
                print("No business hours for \(restaurant.name)")
                return false
            }

            let openHours = businessHours.open

            let isAvailable = currentUser.availableTimes.contains { availableTime in
                openHours.contains { openHour in
                    // Convert openHour.start and openHour.end to minutes since midnight
                    let restaurantStartMinutes = (Int(openHour.start.prefix(2)) ?? 0) * 60 + (Int(openHour.start.suffix(2)) ?? 0)
                    var restaurantEndMinutes = (Int(openHour.end.prefix(2)) ?? 0) * 60 + (Int(openHour.end.suffix(2)) ?? 0)

                    // Adjust end minutes if less than or equal to start minutes
                    if restaurantEndMinutes <= restaurantStartMinutes {
                        restaurantEndMinutes += 24 * 60 // Adjust for overnight or midnight closing
                    }

                    // Similarly, compute user start and end minutes since midnight
                    let userStartMinutes = Calendar.current.component(.hour, from: availableTime.startTime) * 60 + Calendar.current.component(.minute, from: availableTime.startTime)
                    var userEndMinutes = Calendar.current.component(.hour, from: availableTime.endTime) * 60 + Calendar.current.component(.minute, from: availableTime.endTime)

                    // Adjust user end minutes if less than or equal to start minutes
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

                    let isOpen = latestStart < earliestEnd

                    if isOpen {
                        let startHour = latestStart / 60
                        let startMinute = latestStart % 60
                        let endHour = earliestEnd / 60
                        let endMinute = earliestEnd % 60
                        print("\(restaurant.name) is open on day \(openHour.day) from \(startHour):\(String(format: "%02d", startMinute)) to \(endHour):\(String(format: "%02d", endMinute))")
                    }

                    return isOpen
                }
            }

            let matchesPreferences = restaurant.categories.contains { category in
                currentUser.preferences.contains(category.title)
            }

            if isAvailable && matchesPreferences {
                print("\(restaurant.name) matches availability and preferences")
            } else if !isAvailable {
                print("\(restaurant.name) doesn't match availability")
            } else if !matchesPreferences {
                print("\(restaurant.name) doesn't match preferences")
            }

            return isAvailable && matchesPreferences
        }

        print("Found \(recommendedOutings.count) recommended outings")
    }


    
    func sendInvitation(to friends: [User], for restaurant: Restaurant, at time: Date) {
        let invitation = Invitation(from: currentUser, to: friends, restaurant: restaurant, proposedTime: time)
        sentInvitations.append(invitation)
        // In a real app, you would send this invitation to a server or directly to friends
    }
    
    func respondToInvitation(_ invitation: Invitation, accept: Bool) {
        if let index = receivedInvitations.firstIndex(where: { $0.id == invitation.id }) {
            receivedInvitations[index].status = accept ? .accepted : .declined
            if accept {
                // Add to calendar
                addEventToCalendar(invitation: invitation)
            }
        }
    }
    
    func addEventToCalendar(invitation: Invitation) {
        let event = EKEvent(eventStore: eventStore)
        event.title = "Outing to \(invitation.restaurant.name)"
        event.startDate = invitation.proposedTime
        event.endDate = Calendar.current.date(byAdding: .hour, value: 2, to: invitation.proposedTime)!
        event.notes = "Meeting friends at \(invitation.restaurant.name)"
        
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
            
            InvitationsView()
                .tabItem {
                    Label("Invitations", systemImage: "envelope")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .environmentObject(viewModel)
    }
}

struct HomeView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.recommendedOutings) { restaurant in
                        RestaurantCard(restaurant: restaurant)
                    }
                }
                .padding()
            }
            .navigationTitle("Recommended Outings")
        }
    }
}

struct RestaurantCard: View {
    let restaurant: Restaurant
    @EnvironmentObject var viewModel: ContentViewModel
    @State private var showingInviteSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: URL(string: restaurant.imageUrl)) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(height: 200)
            .cornerRadius(10)
            
            Text(restaurant.name)
                .font(.headline)
            
            Text("Rating: \(restaurant.rating, specifier: "%.1f") (\(restaurant.reviewCount) reviews)")
                .font(.subheadline)
            
            Text("Categories: \(restaurant.categories.map { $0.title }.joined(separator: ", "))")
                .font(.subheadline)
            
            if let price = restaurant.price {
                Text("Price: \(price)")
                    .font(.subheadline)
            }
            
            Text("Address: \(restaurant.location.displayAddress.joined(separator: ", "))")
                .font(.subheadline)
            
            if let businessHours = restaurant.businessHours?.first {
                Text("Open: \(businessHours.isOpenNow ? "Yes" : "No")")
                    .font(.subheadline)
            }
            
            HStack {
                Button("Invite Group") {
                    showingInviteSheet = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Link("View on Yelp", destination: URL(string: restaurant.url)!)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
        .sheet(isPresented: $showingInviteSheet) {
            InviteView(restaurant: restaurant)
        }
    }
}

struct InviteView: View {
    let restaurant: Restaurant
    @EnvironmentObject var viewModel: ContentViewModel
    @State private var selectedFriends: Set<UUID> = []
    @State private var invitationDate = Date()
    @Environment(\.presentationMode) var presentationMode
    
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
                        }
                    }
                }
                
                Section(header: Text("Select Date and Time")) {
                    DatePicker("Date and Time", selection: $invitationDate, in: Date()...)
                }
                
                Button("Send Invitation") {
                    let invitedFriends = viewModel.currentUser.friends.filter { selectedFriends.contains($0.id) }
                    viewModel.sendInvitation(to: invitedFriends, for: restaurant, at: invitationDate)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationTitle("Invite Friends")
        }
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
                if self.isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
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
                        InvitationRow(invitation: invitation)
                    }
                }
                
                Section(header: Text("Sent Invitations")) {
                    ForEach(viewModel.sentInvitations) { invitation in
                        Text("\(invitation.restaurant.name) - \(invitation.proposedTime, style: .date)")
                    }
                }
            }
            .navigationTitle("Invitations")
        }
    }
}

struct InvitationRow: View {
    let invitation: Invitation
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(invitation.from.name) invited you to \(invitation.restaurant.name)")
            Text("Date: \(invitation.proposedTime, style: .date)")
            HStack {
                Button("Accept") {
                    viewModel.respondToInvitation(invitation, accept: true)
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Decline") {
                    viewModel.respondToInvitation(invitation, accept: false)
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Info")) {
                    Text("Name: \(viewModel.currentUser.name)")
                    Text("Preferences: \(viewModel.currentUser.preferences.joined(separator: ", "))")
                }
                
                Section(header: Text("Available Times")) {
                    ForEach(viewModel.currentUser.availableTimes) { time in
                        VStack(alignment: .leading) {
                            Text("Day: \(dayName(for: time.weekday))")
                            Text("Start: \(formatTime(time.startTime))")
                            Text("End: \(formatTime(time.endTime))")
                        }
                    }
                }
                
                Section(header: Text("Friends")) {
                    ForEach(viewModel.currentUser.friends) { friend in
                        Text(friend.name)
                    }
                }
            }
            .navigationTitle("Profile")
        }
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

}
