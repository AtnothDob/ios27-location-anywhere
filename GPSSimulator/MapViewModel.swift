import Foundation
import SwiftUI
import MapKit
import Combine

// MARK: - Universal Coordinate Parser

struct CoordinateParser {
    static func parse(text: String) -> (lat: Double, lon: Double)? {
        var str = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        str = str.replacingOccurrences(of: "，", with: ",")
        str = str.replacingOccurrences(of: "；", with: ",")
        str = str.replacingOccurrences(of: ";", with: ",")
        str = str.replacingOccurrences(of: "°", with: "")
        str = str.replacingOccurrences(of: "\"", with: "")
        str = str.replacingOccurrences(of: "“", with: "")
        str = str.replacingOccurrences(of: "”", with: "")
        str = str.replacingOccurrences(of: "’", with: "")
        str = str.replacingOccurrences(of: "'", with: "")

        var isSouth = false
        var isWest = false
        let upper = str.uppercased()
        if upper.contains("S") || upper.contains("南纬") { isSouth = true }
        if upper.contains("W") || upper.contains("西经") { isWest = true }

        var filtered = str
        for token in ["北纬", "南纬", "东经", "西经", "LAT:", "LON:", "LNG:", "LAT", "LON", "LNG", "N", "S", "E", "W"] {
            filtered = filtered.replacingOccurrences(of: token, with: "", options: NSString.CompareOptions.caseInsensitive)
        }

        let parts = filtered.components(separatedBy: CharacterSet(charactersIn: ",/ \t|"))
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count >= 2, let v1 = Double(parts[0]), let v2 = Double(parts[1]) {
            var lat = v1
            var lon = v2
            if abs(v1) > 90.0 && abs(v2) <= 90.0 {
                lat = v2
                lon = v1
            }
            if isSouth && lat > 0 { lat = -lat }
            if isWest && lon > 0 { lon = -lon }
            if lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0 {
                return (lat, lon)
            }
        }
        return nil
    }
}

// MARK: - Search Result Model

struct SearchPlace: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    var sourceTag: String? = nil

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: SearchPlace, rhs: SearchPlace) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Waypoint Model

struct RouteWaypoint: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: RouteWaypoint, rhs: RouteWaypoint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Turn-by-Turn Step Model

struct RouteStepInfo: Identifiable, Hashable {
    let id = UUID()
    let instruction: String
    let distanceMeters: Double
    let coordinate: CLLocationCoordinate2D?

    var distanceDisplay: String {
        if distanceMeters >= 1000 {
            return String(format: "%.1f km", distanceMeters / 1000.0)
        } else {
            return "\(Int(distanceMeters)) m"
        }
    }

    var iconName: String {
        let lower = instruction.lowercased()
        if lower.contains("左转") || lower.contains("turn left") {
            return "arrow.turn.up.left"
        } else if lower.contains("右转") || lower.contains("turn right") {
            return "arrow.turn.up.right"
        } else if lower.contains("掉头") || lower.contains("u-turn") {
            return "arrow.uturn.down"
        } else if lower.contains("靠左") || lower.contains("bear left") {
            return "arrow.up.left"
        } else if lower.contains("靠右") || lower.contains("bear right") {
            return "arrow.up.right"
        } else if lower.contains("到达") || lower.contains("arrive") {
            return "flag.checkered"
        } else if lower.contains("进入") || lower.contains("merge") || lower.contains("ramp") {
            return "arrow.triangle.merge"
        } else {
            return "arrow.up"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: RouteStepInfo, rhs: RouteStepInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Map Style Selection

enum AppMapStyle: String, CaseIterable {
    case standard = "标准"
    case imagery  = "卫星"
    case hybrid   = "混合"

    var mapStyle: MapStyle {
        switch self {
        case .standard: return .standard
        case .imagery:  return .imagery
        case .hybrid:   return .hybrid
        }
    }
}

// MARK: - Map View Model

@MainActor
final class MapViewModel: ObservableObject {
    // Map Camera Position
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
    )

    // Map Style
    @Published var selectedMapStyle: AppMapStyle = .standard

    // Selected Target Marker (where the user clicked or selected)
    @Published var targetCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

    // Waypoints (A -> B -> C -> Destination)
    @Published var waypoints: [RouteWaypoint] = []

    // Route Preferences
    @Published var avoidHighways: Bool = false
    @Published var avoidTolls: Bool = false
    @Published var voiceGuidanceEnabled: Bool = true

    // Route Navigation Coordinates & Polyline
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var routeDestination: CLLocationCoordinate2D? = nil
    @Published var routeDistanceMeters: Double = 0
    @Published var routeExpectedTravelTime: TimeInterval = 0
    @Published var isCalculatingRoute: Bool = false
    @Published var routeError: String? = nil

    // Turn-by-Turn Steps
    @Published var routeSteps: [RouteStepInfo] = []
    @Published var currentStepIndex: Int = 0

    // Location Search
    @Published var searchQuery: String = ""
    @Published var searchResults: [SearchPlace] = []
    @Published var isSearching: Bool = false

    private var searchTask: Task<Void, Never>?

    // MARK: - Camera Tracking & Zoom Control
    var currentCameraCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    var currentCameraDistance: Double = 2500.0
    var currentCameraHeading: Double = 0.0
    var currentCameraPitch: Double = 0.0

    func updateCameraContext(_ context: MapCameraUpdateContext) {
        currentCameraCenter = context.camera.centerCoordinate
        currentCameraDistance = context.camera.distance
        currentCameraHeading = context.camera.heading
        currentCameraPitch = context.camera.pitch
    }

    func zoomIn() {
        let newDistance = max(50.0, currentCameraDistance * 0.5)
        currentCameraDistance = newDistance
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: currentCameraCenter,
                    distance: newDistance,
                    heading: currentCameraHeading,
                    pitch: currentCameraPitch
                )
            )
        }
    }

    func zoomOut() {
        let newDistance = min(25_000_000.0, currentCameraDistance * 2.0)
        currentCameraDistance = newDistance
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: currentCameraCenter,
                    distance: newDistance,
                    heading: currentCameraHeading,
                    pitch: currentCameraPitch
                )
            )
        }
    }

    // MARK: Center on coordinate
    func moveTo(coordinate: CLLocationCoordinate2D, meters: Double = 2000) {
        currentCameraCenter = coordinate
        currentCameraDistance = meters
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: meters,
                    heading: 0,
                    pitch: 0
                )
            )
        }
    }


    // MARK: - Global Search (Apple Maps + OpenStreetMap Nominatim + Photon Fallback + Coordinate Parsing)
    func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        // 1. Direct coordinate entry check
        if let parsed = CoordinateParser.parse(text: trimmed) {
            searchTask?.cancel()
            searchResults = [
                SearchPlace(
                    title: "📍 经纬度坐标直达",
                    subtitle: String(format: "纬度: %.5f, 经度: %.5f", parsed.lat, parsed.lon),
                    coordinate: CLLocationCoordinate2D(latitude: parsed.lat, longitude: parsed.lon),
                    sourceTag: "坐标"
                )
            ]
            isSearching = false
            return
        }

        searchTask?.cancel()
        isSearching = true

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000) // 280ms debounce
            guard !Task.isCancelled else { return }

            async let appleResults = self.fetchAppleMaps(query: trimmed)
            async let globalResults = self.fetchGlobal(query: trimmed)

            let (apple, global) = await (appleResults, globalResults)
            guard !Task.isCancelled else { return }

            var combined: [SearchPlace] = []
            var seenCoords: [CLLocationCoordinate2D] = []

            func isDuplicate(_ coord: CLLocationCoordinate2D) -> Bool {
                for c in seenCoords {
                    let dLat = abs(c.latitude - coord.latitude)
                    let dLon = abs(c.longitude - coord.longitude)
                    if dLat < 0.003 && dLon < 0.003 {
                        return true
                    }
                }
                return false
            }

            // Global search results first (covers international addresses, Irvine, Apple Park, etc.)
            for item in global {
                if !isDuplicate(item.coordinate) {
                    combined.append(item)
                    seenCoords.append(item.coordinate)
                }
            }
            // Apple Maps results (covers local Chinese POIs)
            for item in apple {
                if !isDuplicate(item.coordinate) {
                    combined.append(item)
                    seenCoords.append(item.coordinate)
                }
            }

            self.searchResults = combined
            self.isSearching = false
        }
    }

    private func fetchAppleMaps(query: String) async -> [SearchPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.map { item in
                SearchPlace(
                    title: item.name ?? "未知地点",
                    subtitle: item.placemark.title ?? "",
                    coordinate: item.placemark.coordinate,
                    sourceTag: "Apple"
                )
            }
        } catch {
            return []
        }
    }

    private func fetchGlobal(query: String) async -> [SearchPlace] {
        if let nominatim = await fetchNominatim(query: query), !nominatim.isEmpty {
            return nominatim
        }
        return await fetchPhoton(query: query)
    }

    private func fetchNominatim(query: String) async -> [SearchPlace]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://nominatim.openstreetmap.org/search?q=\(encoded)&format=json&limit=6&accept-language=zh-CN,zh,en") else {
            return nil
        }
        var req = URLRequest(url: url)
        req.setValue("GPSSimulator/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 3.0

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else { return nil }
            struct Item: Decodable {
                let lat: String
                let lon: String
                let display_name: String
                let name: String?
            }
            let list = try JSONDecoder().decode([Item].self, from: data)
            return list.compactMap { p in
                guard let lat = Double(p.lat), let lon = Double(p.lon) else { return nil }
                let parts = p.display_name.components(separatedBy: ",")
                let title = (p.name?.isEmpty == false ? p.name! : parts.first?.trimmingCharacters(in: .whitespaces)) ?? "未知地点"
                let subtitle = parts.dropFirst().joined(separator: ", ").trimmingCharacters(in: .whitespaces)
                return SearchPlace(title: title, subtitle: subtitle, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), sourceTag: "全球")
            }
        } catch {
            return nil
        }
    }

    private func fetchPhoton(query: String) async -> [SearchPlace] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://photon.komoot.io/api/?q=\(encoded)&limit=6&lang=default") else {
            return []
        }
        var req = URLRequest(url: url)
        req.setValue("GPSSimulator/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 3.0

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else { return [] }
            struct Feature: Decodable {
                struct Properties: Decodable {
                    let name: String?
                    let city: String?
                    let state: String?
                    let country: String?
                }
                struct Geometry: Decodable {
                    let coordinates: [Double]
                }
                let properties: Properties
                let geometry: Geometry
            }
            struct PhotonResponse: Decodable {
                let features: [Feature]
            }
            let res = try JSONDecoder().decode(PhotonResponse.self, from: data)
            return res.features.compactMap { f in
                guard f.geometry.coordinates.count >= 2 else { return nil }
                let lon = f.geometry.coordinates[0]
                let lat = f.geometry.coordinates[1]
                let title = f.properties.name ?? f.properties.city ?? "未知地点"
                let subParts = [f.properties.city, f.properties.state, f.properties.country].compactMap { $0 }.filter { $0 != title }
                let subtitle = subParts.joined(separator: ", ")
                return SearchPlace(title: title, subtitle: subtitle, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), sourceTag: "全球")
            }
        } catch {
            return []
        }
    }


    // MARK: Waypoint Management
    func addWaypoint(coordinate: CLLocationCoordinate2D, name: String? = nil) {
        let count = waypoints.count + 1
        let title = name ?? "途经点 \(count)"
        waypoints.append(RouteWaypoint(name: title, coordinate: coordinate))
    }

    func removeWaypoint(id: UUID) {
        waypoints.removeAll { $0.id == id }
    }

    func clearWaypoints() {
        waypoints.removeAll()
    }

    // MARK: Multi-Leg Route Calculation via Apple Maps MKDirections
    func calculateRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .automobile) async -> Bool {
        isCalculatingRoute = true
        routeError = nil
        currentStepIndex = 0

        // 构造完整有序途经点序列: 起点 -> 途经点1..N -> 终点
        var stops: [CLLocationCoordinate2D] = [start]
        stops.append(contentsOf: waypoints.map(\.coordinate))
        stops.append(destination)

        var combinedCoords: [CLLocationCoordinate2D] = []
        var combinedSteps: [RouteStepInfo] = []
        var totalDist: Double = 0
        var totalTime: TimeInterval = 0
        var fullMapRect: MKMapRect? = nil

        do {
            for i in 0..<(stops.count - 1) {
                let legStart = stops[i]
                let legEnd = stops[i + 1]

                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: legStart))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: legEnd))
                request.transportType = transportType
                request.requestsAlternateRoutes = false
                request.highwayPreference = avoidHighways ? .avoid : .any
                request.tollPreference = avoidTolls ? .avoid : .any

                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                guard let route = response.routes.first else {
                    throw NSError(domain: "MapViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "段落 \(i+1) 未找到可行路线"])
                }

                // 提取 Polyline
                var legCoords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
                route.polyline.getCoordinates(&legCoords, range: NSRange(location: 0, length: route.polyline.pointCount))
                combinedCoords.append(contentsOf: legCoords)

                // 提取 Steps
                for step in route.steps {
                    let text = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }
                    var stepCoord: CLLocationCoordinate2D? = nil
                    if step.polyline.pointCount > 0 {
                        var c = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: 1)
                        step.polyline.getCoordinates(&c, range: NSRange(location: 0, length: 1))
                        stepCoord = c.first
                    }
                    combinedSteps.append(RouteStepInfo(
                        instruction: text,
                        distanceMeters: step.distance,
                        coordinate: stepCoord
                    ))
                }

                totalDist += route.distance
                totalTime += route.expectedTravelTime

                if let currentRect = fullMapRect {
                    fullMapRect = currentRect.union(route.polyline.boundingMapRect)
                } else {
                    fullMapRect = route.polyline.boundingMapRect
                }
            }

            self.routeCoordinates = combinedCoords
            self.routeSteps = combinedSteps
            self.routeDestination = destination
            self.routeDistanceMeters = totalDist
            self.routeExpectedTravelTime = totalTime
            self.isCalculatingRoute = false

            if let rect = fullMapRect {
                self.cameraPosition = .rect(rect)
            }

            return true
        } catch {
            self.routeError = "路线计算失败: \(error.localizedDescription)"
            self.isCalculatingRoute = false
            return false
        }
    }

    func clearRoute() {
        routeCoordinates = []
        routeSteps = []
        currentStepIndex = 0
        routeDestination = nil
        routeDistanceMeters = 0
        routeExpectedTravelTime = 0
        routeError = nil
    }
}
