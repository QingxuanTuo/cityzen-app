# CityZen

An intelligent environmental health assistant application that helps urban residents understand real-time environmental conditions, make informed daily life decisions, and reduce environmental exposure risks.

## Application Positioning

CityZen is designed for high-pollution European cities such as Milan, Italy. Considering the reality of an aging society, it focuses on:
- Daily environmental exposure risk assessment
- Outdoor timing and route recommendations
- Indoor/outdoor activity selection guidance
- Health protection measure reminders

## Key Features

### 🏠 Home
- Real-time weather and air quality monitoring
- Intelligent lifestyle suggestions based on environmental conditions
- Beautiful weather visualization and trend charts

### 🗺️ Map
- Interactive environmental data map (AQI, PM2.5, Ozone, Precipitation)
- Nearby parks and green space discovery
- Location-based environmental insights

### 🤖 AI Assistant
- Google Gemini-powered environmental health intelligent assistant
- Personalized daily activity recommendations
- Environmental exposure risk assessment
- Interactive conversations with AI assistant

### ⚙️ Settings
- Multi-AI provider support (Gemini, OpenAI, Claude)
- Customizable health thresholds and preference settings
- Location services and unit preferences

## Tech Stack

- **Flutter** - Cross-platform mobile framework
- **Google Gemini AI** - Intelligent recommendation system
- **OpenMeteo API** - Weather and air quality data
- **OpenStreetMap** - Map and location services
- **Flutter Map** - Interactive map visualization
- **FL Chart** - Data visualization

## Quick Start

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Configure AI service (optional): Add your API key in Settings
4. Run the app: `flutter run`

## Environmental Data APIs

- Weather Data: [Open-Meteo](https://open-meteo.com/)
- Air Quality: [Open-Meteo Air Quality API](https://open-meteo.com/en/docs/air-quality-api)
- Park Data: [Overpass API](https://overpass-api.de/) (OpenStreetMap)

## Responsive Design

CityZen supports multiple screen sizes and orientations:
- **Mobile**: Optimized for phones (< 600px width)
- **Tablet**: Enhanced layout for tablets (600px - 1200px width)
- **Desktop**: Full-featured desktop experience (> 1200px width)

## Testing

The app includes comprehensive unit and widget tests. Run tests with:
```bash
flutter test
```

See `TEST_PLAN.md` for detailed test coverage and scenarios.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── pages/                    # Screen pages
│   ├── simplified_map_page.dart
│   ├── tablet_home_page.dart
│   └── ...
├── services/                 # Business logic services
│   ├── ai_service.dart
│   ├── environment_data_service.dart
│   └── ...
├── responsive/               # Responsive layout components
└── theme/                    # App theming
```

## License

This project is licensed under the MIT License.
