import 'package:flutter/material.dart';
import 'package:cityzen/environment_data.dart';
import 'package:cityzen/ai_service.dart';
import 'package:cityzen/theme/app_theme.dart';
import 'package:cityzen/responsive/responsive_layout.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Tablet-optimized Master-Detail layout for environmental data
/// Left panel: Environmental data overview and controls
/// Right panel: Detailed analysis and AI recommendations
class TabletHomePage extends StatefulWidget {
  const TabletHomePage({super.key});

  @override
  State<TabletHomePage> createState() => _TabletHomePageState();
}

class _TabletHomePageState extends State<TabletHomePage> {
  final EnvironmentDataManager _envManager = EnvironmentDataManager();
  late final GeminiAIService _aiService;
  
  bool _loading = false;
  String? _error;
  WeatherResult? _result;
  List<double> _pm25Trend = [];
  String _selectedDetailView = 'overview'; // 'overview', 'trends', 'ai_advice'
  String _aiAdvice = '';
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _aiService = GeminiAIService();
    _fetchWeather();
    _envManager.addListener(_onEnvironmentDataChanged);
  }

  @override
  void dispose() {
    _envManager.removeListener(_onEnvironmentDataChanged);
    super.dispose();
  }

  void _onEnvironmentDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      const lat = 45.4809167;
      const lon = 9.2251111;

      // Fetch weather data
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,wind_speed_10m,weathercode,relative_humidity_2m'
        '&timezone=auto',
      );

      // Fetch air quality data
      final aqUri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality'
        '?latitude=$lat&longitude=$lon'
        '&hourly=pm10,pm2_5'
        '&timezone=auto',
      );

      final responses = await Future.wait([
        http.get(uri).timeout(const Duration(seconds: 10)),
        http.get(aqUri).timeout(const Duration(seconds: 10)),
      ]);

      final weatherResp = responses[0];
      final aqResp = responses[1];

      if (weatherResp.statusCode != 200 || aqResp.statusCode != 200) {
        throw Exception('API request failed');
      }

      final weatherJson = jsonDecode(weatherResp.body) as Map<String, dynamic>;
      final aqJson = jsonDecode(aqResp.body) as Map<String, dynamic>;

      final current = weatherJson['current'] as Map<String, dynamic>?;
      final aqHourly = aqJson['hourly'] as Map<String, dynamic>?;

      double? latestNonNull(List<dynamic>? list) {
        if (list == null) return null;
        for (var i = list.length - 1; i >= 0; i--) {
          final v = list[i];
          if (v is num) return v.toDouble();
        }
        return null;
      }

      final pm25 = latestNonNull(aqHourly?['pm2_5'] as List?);
      final pm10 = latestNonNull(aqHourly?['pm10'] as List?);
      final pm25List = (aqHourly?['pm2_5'] as List?) ?? [];
      final trend = pm25List
          .where((e) => e is num)
          .map((e) => (e as num).toDouble())
          .toList();

      final sampled = <double>[];
      for (int i = 0; i < trend.length && sampled.length < 12; i += 2) {
        sampled.add(trend[i]);
      }

      final temp = (current?['temperature_2m'] as num?)?.toDouble();
      final wind = (current?['wind_speed_10m'] as num?)?.toDouble();
      final weatherCode = current?['weathercode'] as int?;
      final humidity = (current?['relative_humidity_2m'] as num?)?.toDouble();

      final result = WeatherResult(
        temperatureC: temp,
        windKmh: wind,
        weatherCode: weatherCode,
        pm25: pm25,
        pm10: pm10,
        humidity: humidity,
      );

      setState(() {
        _result = result;
        _pm25Trend = sampled;
      });

      _envManager.updateData(EnvironmentData.fromWeatherResult(result));
      
      // Auto-generate AI advice for tablet view
      _generateAIAdvice();

    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generateAIAdvice() async {
    if (_result == null) return;
    
    setState(() => _aiLoading = true);
    
    try {
      final advice = await _aiService.getEnvironmentalAdvice(
        userMessage: 'Provide comprehensive environmental health analysis for current conditions',
        pm25: _result!.pm25,
        pm10: _result!.pm10,
        windSpeed: _result!.windKmh,
        temperature: _result!.temperatureC,
        weatherCode: _result!.weatherCode,
        city: 'Milan',
      );
      
      setState(() => _aiAdvice = advice);
    } catch (e) {
      setState(() => _aiAdvice = 'AI analysis unavailable. Please configure your Gemini API key in Settings.');
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CityZen - Environmental Health Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchWeather,
          ),
        ],
      ),
      body: Row(
        children: [
          // Master Panel (Left) - Environmental Data Overview
          SizedBox(
            width: 400,
            child: _buildMasterPanel(),
          ),
          
          // Divider
          const VerticalDivider(width: 1),
          
          // Detail Panel (Right) - Detailed Analysis
          Expanded(
            child: _buildDetailPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Milan, Italy',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Current Conditions
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(child: Text('Error: $_error'))
          else if (_result != null)
            _buildCurrentConditions()
          else
            const Center(child: Text('No data available')),
          
          const SizedBox(height: 24),
          
          // Detail View Selector
          const Text(
            'Detailed Analysis',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          _buildDetailSelector(),
          
          const Spacer(),
          
          // Quick Actions
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildCurrentConditions() {
    final r = _result!;
    return Column(
      children: [
        // Temperature Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.thermostat, size: 32, color: AppColors.primary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.temperatureC == null ? '—' : '${r.temperatureC!.toStringAsFixed(1)}°C',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text('Temperature'),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Air Quality Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.air, size: 32, color: _pmColor(r.pm25)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.pm25 == null ? '—' : '${r.pm25!.toStringAsFixed(1)} µg/m³',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(_airQualityTag(r.pm25).label),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Wind & Humidity Row
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Icon(Icons.air, color: Colors.blue),
                      const SizedBox(height: 4),
                      Text(
                        r.windKmh == null ? '—' : '${r.windKmh!.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('km/h', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Icon(Icons.water_drop, color: Colors.blue),
                      const SizedBox(height: 4),
                      Text(
                        r.humidity == null ? '—' : '${r.humidity!.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('%', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailSelector() {
    return Column(
      children: [
        _buildSelectorButton('overview', 'Overview', Icons.dashboard),
        _buildSelectorButton('trends', 'Trends', Icons.trending_up),
        _buildSelectorButton('ai_advice', 'AI Analysis', Icons.psychology),
      ],
    );
  }

  Widget _buildSelectorButton(String value, String label, IconData icon) {
    final isSelected = _selectedDetailView == value;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primary : Colors.black87,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppColors.primary.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => setState(() => _selectedDetailView = value),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _fetchWeather,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Data'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _generateAIAdvice(),
            icon: const Icon(Icons.psychology),
            label: const Text('Get AI Advice'),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: _buildDetailContent(),
    );
  }

  Widget _buildDetailContent() {
    switch (_selectedDetailView) {
      case 'trends':
        return _buildTrendsView();
      case 'ai_advice':
        return _buildAIAdviceView();
      default:
        return _buildOverviewView();
    }
  }

  Widget _buildOverviewView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Environmental Overview',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        if (_result != null) ...[
          _buildOverviewCards(),
          const SizedBox(height: 24),
          _buildHealthRecommendations(),
        ] else
          const Center(child: Text('No data available')),
      ],
    );
  }

  Widget _buildOverviewCards() {
    final r = _result!;
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Air Quality Index', _getAQIScore(r.pm25), _pmColor(r.pm25)),
        _buildMetricCard('Weather Comfort', _getComfortScore(r), Colors.blue),
        _buildMetricCard('Outdoor Activity', _getActivityScore(r), Colors.green),
        _buildMetricCard('Health Risk', _getHealthRisk(r), Colors.orange),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Air Quality Trends',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        if (_pm25Trend.isNotEmpty) ...[
          // 图表标题和图例
          Row(
            children: [
              const Text(
                'PM2.5 Concentration (µg/m³)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _buildChartLegend(),
            ],
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}');
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final hour = (value.toInt() * 2) % 24;
                        return Text('${hour.toString().padLeft(2, '0')}:00');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: _pm25Trend.asMap().entries.map((e) => 
                      FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 空气质量等级说明
          _buildAirQualityLegend(),
          
          const SizedBox(height: 12),
          const Text(
            'PM2.5 levels over the last 24 hours. Lower values indicate better air quality.',
            style: TextStyle(color: Colors.grey),
          ),
        ] else
          const Center(child: Text('No trend data available')),
      ],
    );
  }

  // 图表图例
  Widget _buildChartLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'PM2.5 Trend',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // 空气质量等级图例
  Widget _buildAirQualityLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Air Quality Index (EAQI)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: _buildAQILegendItem('Good', const Color(0xFF4CAF50), '0-15 µg/m³'),
              ),
              Expanded(
                child: _buildAQILegendItem('Fair', const Color(0xFF8BC34A), '16-25 µg/m³'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildAQILegendItem('Moderate', const Color(0xFFFFEB3B), '26-50 µg/m³'),
              ),
              Expanded(
                child: _buildAQILegendItem('Poor', const Color(0xFFFF9800), '51-90 µg/m³'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildAQILegendItem('Very Poor', const Color(0xFFF44336), '91-140 µg/m³'),
              ),
              Expanded(
                child: _buildAQILegendItem('Extremely Poor', const Color(0xFF9C27B0), '>140 µg/m³'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 空气质量图例项
  Widget _buildAQILegendItem(String label, Color color, String range) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  range,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAdviceView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Environmental Analysis',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        if (_aiLoading)
          const Center(child: CircularProgressIndicator())
        else if (_aiAdvice.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _aiAdvice,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              ),
            ),
          )
        else
          const Center(child: Text('No AI analysis available')),
      ],
    );
  }

  Widget _buildHealthRecommendations() {
    final recommendations = _getHealthRecommendations();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Recommendations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...recommendations.map((rec) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(rec['icon'] as IconData, color: rec['color'] as Color),
            title: Text(rec['title'] as String),
            subtitle: Text(rec['description'] as String),
          ),
        )),
      ],
    );
  }

  // Helper methods
  ({String label, Color color}) _airQualityTag(double? pm25) {
    if (pm25 == null) return (label: 'No data', color: Colors.grey);
    if (pm25 <= 5) return (label: 'Good', color: Colors.green);
    if (pm25 <= 15) return (label: 'Fair', color: Colors.lightGreen);
    if (pm25 <= 50) return (label: 'Moderate', color: Colors.amber);
    if (pm25 <= 90) return (label: 'Poor', color: Colors.orange);
    if (pm25 <= 140) return (label: 'Very poor', color: Colors.red);
    return (label: 'Extremely poor', color: Colors.purple);
  }

  Color _pmColor(double? pm25) => _airQualityTag(pm25).color;

  String _getAQIScore(double? pm25) {
    if (pm25 == null) return '—';
    if (pm25 <= 15) return 'Good';
    if (pm25 <= 50) return 'Moderate';
    return 'Poor';
  }

  String _getComfortScore(WeatherResult r) {
    final temp = r.temperatureC ?? 20;
    if (temp >= 18 && temp <= 24) return 'Excellent';
    if (temp >= 15 && temp <= 28) return 'Good';
    return 'Fair';
  }

  String _getActivityScore(WeatherResult r) {
    final pm25 = r.pm25 ?? 0;
    final temp = r.temperatureC ?? 20;
    if (pm25 <= 15 && temp >= 15 && temp <= 25) return 'Excellent';
    if (pm25 <= 35) return 'Good';
    return 'Limited';
  }

  String _getHealthRisk(WeatherResult r) {
    final pm25 = r.pm25 ?? 0;
    if (pm25 <= 15) return 'Low';
    if (pm25 <= 50) return 'Moderate';
    return 'High';
  }

  List<Map<String, dynamic>> _getHealthRecommendations() {
    final r = _result;
    if (r == null) return [];

    final recommendations = <Map<String, dynamic>>[];
    final pm25 = r.pm25 ?? 0;
    final temp = r.temperatureC ?? 20;

    if (pm25 <= 15) {
      recommendations.add({
        'icon': Icons.directions_run,
        'color': Colors.green,
        'title': 'Great for outdoor exercise',
        'description': 'Air quality is excellent for all outdoor activities',
      });
    } else if (pm25 > 35) {
      recommendations.add({
        'icon': Icons.home,
        'color': Colors.orange,
        'title': 'Consider indoor activities',
        'description': 'High pollution levels may affect sensitive individuals',
      });
    }

    if (temp < 10) {
      recommendations.add({
        'icon': Icons.ac_unit,
        'color': Colors.blue,
        'title': 'Dress warmly',
        'description': 'Low temperatures require appropriate clothing',
      });
    } else if (temp > 30) {
      recommendations.add({
        'icon': Icons.wb_sunny,
        'color': Colors.orange,
        'title': 'Stay hydrated',
        'description': 'High temperatures increase dehydration risk',
      });
    }

    return recommendations;
  }
}