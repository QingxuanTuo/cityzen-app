import 'package:flutter/material.dart';
import 'package:cityzen/responsive/responsive_layout.dart';
import 'package:cityzen/environment_data.dart';

/// 环境数据Master-Detail页面
/// 展示响应式布局的核心功能
class EnvironmentalDataMasterDetail extends StatefulWidget {
  const EnvironmentalDataMasterDetail({super.key});

  @override
  State<EnvironmentalDataMasterDetail> createState() => _EnvironmentalDataMasterDetailState();
}

class _EnvironmentalDataMasterDetailState extends State<EnvironmentalDataMasterDetail> {
  int? selectedLocationIndex;
  final List<LocationData> locations = [
    LocationData(
      name: 'Milan Centro',
      coordinates: '45.4642°N, 9.1900°E',
      pm25: 25.3,
      pm10: 35.7,
      temperature: 18.5,
      humidity: 65,
      windSpeed: 12.3,
      aqi: 78,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    LocationData(
      name: 'Milan Porta Garibaldi',
      coordinates: '45.4853°N, 9.1877°E',
      pm25: 32.1,
      pm10: 42.8,
      temperature: 19.2,
      humidity: 62,
      windSpeed: 8.7,
      aqi: 85,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    LocationData(
      name: 'Milan Navigli',
      coordinates: '45.4484°N, 9.1696°E',
      pm25: 28.9,
      pm10: 38.4,
      temperature: 18.8,
      humidity: 68,
      windSpeed: 15.2,
      aqi: 82,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 22)),
    ),
    LocationData(
      name: 'Milan Brera',
      coordinates: '45.4719°N, 9.1881°E',
      pm25: 22.7,
      pm10: 31.5,
      temperature: 17.9,
      humidity: 70,
      windSpeed: 9.8,
      aqi: 72,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    LocationData(
      name: 'Milan Lambrate',
      coordinates: '45.4967°N, 9.2264°E',
      pm25: 35.6,
      pm10: 48.2,
      temperature: 19.8,
      humidity: 58,
      windSpeed: 11.4,
      aqi: 92,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environmental Data'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: ResponsiveLayout(
        mobileLayout: _buildMobileLayout(),
        tabletLayout: _buildTabletLayout(),
      ),
    );
  }

  /// 手机布局：传统的列表页面
  Widget _buildMobileLayout() {
    return ListView.builder(
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final location = locations[index];
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getAQIColor(location.aqi),
              child: Text(
                location.aqi.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(location.name),
            subtitle: Text(
              'PM2.5: ${location.pm25.toStringAsFixed(1)} µg/m³\n'
              'Temperature: ${location.temperature.toStringAsFixed(1)}°C',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationDetailPage(location: location),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 平板布局：Master-Detail布局
  Widget _buildTabletLayout() {
    return MasterDetailLayout(
      masterPanel: _buildMasterPanel(),
      detailPanel: selectedLocationIndex != null
          ? _buildDetailPanel(locations[selectedLocationIndex!])
          : _buildEmptyDetailPanel(),
    );
  }

  /// Master Panel：位置列表
  Widget _buildMasterPanel() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.green.shade700,
            child: const Row(
              children: [
                Icon(Icons.location_on, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Locations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                final isSelected = selectedLocationIndex == index;
                
                return Container(
                  color: isSelected ? Colors.green.shade100 : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getAQIColor(location.aqi),
                      radius: 20,
                      child: Text(
                        location.aqi.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      location.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'PM2.5: ${location.pm25.toStringAsFixed(1)} µg/m³',
                      style: TextStyle(
                        color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        selectedLocationIndex = index;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Detail Panel：详细信息
  Widget _buildDetailPanel(LocationData location) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _getAQIColor(location.aqi),
                radius: 30,
                child: Text(
                  location.aqi.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      location.coordinates,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Updated ${_formatTimeAgo(location.lastUpdated)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // 空气质量指标
          _buildSectionTitle('Air Quality'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'PM2.5',
                  '${location.pm25.toStringAsFixed(1)} µg/m³',
                  _getPM25Status(location.pm25),
                  _getPM25Color(location.pm25),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'PM10',
                  '${location.pm10.toStringAsFixed(1)} µg/m³',
                  _getPM10Status(location.pm10),
                  _getPM10Color(location.pm10),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 天气指标
          _buildSectionTitle('Weather Conditions'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Temperature',
                  '${location.temperature.toStringAsFixed(1)}°C',
                  'Current',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Humidity',
                  '${location.humidity}%',
                  'Relative',
                  Colors.blue,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildMetricCard(
            'Wind Speed',
            '${location.windSpeed.toStringAsFixed(1)} km/h',
            'Current',
            Colors.teal,
          ),
          
          const SizedBox(height: 32),
          
          // 健康建议
          _buildSectionTitle('Health Recommendations'),
          const SizedBox(height: 16),
          _buildHealthRecommendations(location),
        ],
      ),
    );
  }

  /// 空详情面板
  Widget _buildEmptyDetailPanel() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Select a location to view details',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String status, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthRecommendations(LocationData location) {
    final recommendations = _getHealthRecommendations(location);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety,
                  color: recommendations['color'] as Color,
                ),
                const SizedBox(width: 8),
                Text(
                  recommendations['title'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recommendations['description'] as String,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            ...((recommendations['tips'] as List<String>).map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(tip, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getAQIColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow.shade700;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    return Colors.purple;
  }

  Color _getPM25Color(double pm25) {
    if (pm25 <= 12) return Colors.green;
    if (pm25 <= 35) return Colors.yellow.shade700;
    if (pm25 <= 55) return Colors.orange;
    return Colors.red;
  }

  Color _getPM10Color(double pm10) {
    if (pm10 <= 20) return Colors.green;
    if (pm10 <= 50) return Colors.yellow.shade700;
    if (pm10 <= 100) return Colors.orange;
    return Colors.red;
  }

  String _getPM25Status(double pm25) {
    if (pm25 <= 12) return 'Good';
    if (pm25 <= 35) return 'Moderate';
    if (pm25 <= 55) return 'Unhealthy';
    return 'Hazardous';
  }

  String _getPM10Status(double pm10) {
    if (pm10 <= 20) return 'Good';
    if (pm10 <= 50) return 'Moderate';
    if (pm10 <= 100) return 'Unhealthy';
    return 'Hazardous';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Map<String, dynamic> _getHealthRecommendations(LocationData location) {
    final avgPM = (location.pm25 + location.pm10) / 2;
    
    if (avgPM <= 25) {
      return {
        'title': 'Good Air Quality',
        'color': Colors.green,
        'description': 'Air quality is satisfactory for most people.',
        'tips': [
          'Great day for outdoor activities',
          'Perfect for walking or light exercise',
          'Windows can be opened for ventilation',
        ],
      };
    } else if (avgPM <= 50) {
      return {
        'title': 'Moderate Air Quality',
        'color': Colors.orange,
        'description': 'Air quality is acceptable for most people, but sensitive individuals may experience minor issues.',
        'tips': [
          'Limit prolonged outdoor activities',
          'Consider wearing a mask if sensitive',
          'Avoid busy traffic areas',
        ],
      };
    } else {
      return {
        'title': 'Poor Air Quality',
        'color': Colors.red,
        'description': 'Air quality is unhealthy. Everyone may experience health effects.',
        'tips': [
          'Avoid outdoor activities',
          'Keep windows closed',
          'Use air purifier indoors',
          'Wear N95 mask if going outside',
        ],
      };
    }
  }
}

/// 位置数据模型
class LocationData {
  final String name;
  final String coordinates;
  final double pm25;
  final double pm10;
  final double temperature;
  final int humidity;
  final double windSpeed;
  final int aqi;
  final DateTime lastUpdated;

  LocationData({
    required this.name,
    required this.coordinates,
    required this.pm25,
    required this.pm10,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.aqi,
    required this.lastUpdated,
  });
}

/// 手机端详情页面
class LocationDetailPage extends StatelessWidget {
  final LocationData location;

  const LocationDetailPage({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(location.name),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 这里可以复用平板版本的详情内容
            Text(
              'Location Details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text('PM2.5: ${location.pm25.toStringAsFixed(1)} µg/m³'),
            Text('PM10: ${location.pm10.toStringAsFixed(1)} µg/m³'),
            Text('Temperature: ${location.temperature.toStringAsFixed(1)}°C'),
            Text('Humidity: ${location.humidity}%'),
            Text('Wind Speed: ${location.windSpeed.toStringAsFixed(1)} km/h'),
            Text('AQI: ${location.aqi}'),
          ],
        ),
      ),
    );
  }
}