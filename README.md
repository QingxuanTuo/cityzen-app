# CityZen

An intelligent urban health companion app that helps city dwellers make informed decisions about outdoor activities by combining real-time environmental data with AI-powered recommendations.

## Features

### 🏠 Home
- Real-time weather and air quality monitoring
- Smart activity recommendations based on environmental conditions
- Beautiful UI with weather visualizations and trend charts

### 🗺️ Map
- Interactive map with environmental data layers (AQI, PM2.5, Ozone, Precipitation)
- Nearby parks and green spaces discovery
- Location-based environmental insights

### 🏃 Activity
- AI-powered fitness coach using Google Gemini
- Personalized workout recommendations based on current conditions
- Activity tracking with environmental scoring
- Interactive chat with AI coach

### ⚙️ Settings
- Multiple AI provider support (Gemini, OpenAI, Claude)
- Customizable health thresholds and preferences
- Location services and unit preferences

## Tech Stack

- **Flutter** - Cross-platform mobile framework
- **Google Gemini AI** - Intelligent recommendations
- **OpenMeteo API** - Weather and air quality data
- **OpenStreetMap** - Maps and location services
- **Flutter Map** - Interactive map visualization
- **FL Chart** - Data visualization

## Getting Started

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Configure AI service (optional): Add your API key in Settings
4. Run the app: `flutter run`

## Environment APIs

- Weather data: [Open-Meteo](https://open-meteo.com/)
- Air quality: [Open-Meteo Air Quality API](https://open-meteo.com/en/docs/air-quality-api)
- Parks data: [Overpass API](https://overpass-api.de/) (OpenStreetMap)

## License

This project is licensed under the MIT License.
