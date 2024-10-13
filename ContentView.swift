import SwiftUI
import EventKit

// MARK: - Models
struct User: Identifiable {
    let id = UUID()
    var name: String
    var preferences: [String]
    var friends: [User]
}

struct YelpResponse: Decodable {
    let businesses: [Restaurant]
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
    
    enum CodingKeys: String, CodingKey {
        case id, name, rating, location, phone, url, categories
        case imageUrl = "image_url"
        case reviewCount = "review_count"
        case price
        case isClosed = "is_closed"
    }
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

// MARK: - ViewModel
class ContentViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var restaurants: [Restaurant] = []
    @Published var availability: [Date] = []
    
    let eventStore = EKEventStore()
    
    init() {
        // Mock user data
        self.currentUser = User(name: "John Doe", preferences: ["Italian", "Japanese"], friends: [])
    }
    
    // Request Calendar Access
    func requestCalendarAccess() {
        eventStore.requestFullAccessToEvents { granted, error in
            if granted {
                self.fetchCalendarEvents()
            } else {
                print("Calendar access denied.")
            }
        }
    }
    
    // Fetch Calendar Events
    func fetchCalendarEvents() {
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        
        let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now)!
        let predicate = eventStore.predicateForEvents(withStart: now, end: oneMonthLater, calendars: calendars)
        
        let events = eventStore.events(matching: predicate)
        
        DispatchQueue.main.async {
            self.availability = events.map { $0.startDate }
        }
    }
    
    // Fetch Yelp Restaurants
    func fetchRestaurants() {
        let apiKey = "tuhu5KX82xiVBfNPwQeC0n-vesx7mDDo1OJul7PPmqsrDMrigjc2eDMp0CSamwUkUricjlrRooufMt8UpBMjGHiEN1d22708MvVnFCd99ClkkRCkl185umQwX28LZ3Yx"
        let url = URL(string: "https://api.yelp.com/v3/businesses/search?location=New+York&term=restaurants&open_now=true")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Request Error: \(error)")
                return
            }
            
            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode(YelpResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.restaurants = decodedResponse.businesses
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                }
            }
        }.resume()
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
            
            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
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
            List(viewModel.restaurants) { restaurant in
                RestaurantRow(restaurant: restaurant)
            }
            .navigationTitle("Restaurants")
        }
        .onAppear {
            viewModel.fetchRestaurants()
        }
    }
}

struct RestaurantRow: View {
    let restaurant: Restaurant
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: URL(string: restaurant.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .cornerRadius(10)
            } placeholder: {
                ProgressView()
            }
            
            Text(restaurant.name)
                .font(.headline)
            
            Text(restaurant.location.displayAddress.joined(separator: ", "))
                .font(.subheadline)
            
            HStack {
                Text("Rating: \(restaurant.rating, specifier: "%.1f")")
                Text("(\(restaurant.reviewCount) reviews)")
                    .foregroundColor(.secondary)
            }
            
            if let price = restaurant.price {
                Text("Price: \(price)")
            }
            
            Text("Categories: \(restaurant.categories.map { $0.title }.joined(separator: ", "))")
            
            Text("Phone: \(restaurant.phone)")
            
            Text(!restaurant.isClosed ? "Open Now" : "Closed")
                .foregroundColor(!restaurant.isClosed ? .green : .red)
            
            Link("View on Yelp", destination: URL(string: restaurant.url)!)
        }
        .padding(.vertical)
    }
}

struct PlanView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationView {
            List(viewModel.availability, id: \.self) { date in
                Text(date, style: .date)
            }
            .navigationTitle("Available Times")
        }
        .onAppear {
            viewModel.requestCalendarAccess()
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Info")) {
                    Text("Name: \(viewModel.currentUser?.name ?? "")")
                    Text("Preferences: \(viewModel.currentUser?.preferences.joined(separator: ", ") ?? "")")
                }
                
                Section(header: Text("Friends")) {
                    Text("Coming soon...")
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
