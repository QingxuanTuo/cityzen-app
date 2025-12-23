import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  debugPrint('CITYZEN MAIN LOADED');
  runApp(const CityZenApp());
}

class CityZenApp extends StatelessWidget {
  const CityZenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CityZen',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [HomePage(), MapPage(), ActivityPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = false;
  String? _error;
  WeatherResult? _result;

  @override
  void initState() {
    super.initState();
    _fetchWeather(); // 启动时自动加载一次
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 先固定一个城市坐标：Milan（你们后面再做定位/城市选择）
      const lat = 45.4642;
      const lon = 9.1900;

      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,wind_speed_10m'
        '&hourly=pm10,pm2_5'
        '&timezone=auto',
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      final current = jsonMap['current'] as Map<String, dynamic>?;

      final temp = (current?['temperature_2m'] as num?)?.toDouble();
      final wind = (current?['wind_speed_10m'] as num?)?.toDouble();

      // PM2.5 / PM10 取 hourly 的第一项（最简单可跑版）
      final hourly = jsonMap['hourly'] as Map<String, dynamic>?;

      double? firstNum(dynamic v) {
        if (v is List && v.isNotEmpty) {
          final x = v.first;
          if (x is num) return x.toDouble();
        }
        return null;
      }

      final pm25 = firstNum(hourly?['pm2_5']);
      final pm10 = firstNum(hourly?['pm10']);

      final result = WeatherResult(
        temperatureC: temp,
        windKmh: wind,
        pm25: pm25,
        pm10: pm10,
      );

      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _suggestion(WeatherResult r) {
    // 超简化版“建议逻辑”：先凑出一个可展示的“智能分析”
    final pm25 = r.pm25 ?? 0;
    final wind = r.windKmh ?? 0;
    if (pm25 >= 35) return '空气一般：建议室内训练或轻量散步。';
    if (wind >= 30) return '风有点大：建议骑行注意安全，或选择跑步。';
    return '适合户外运动：可以跑步/骑行。';
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CityZen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchWeather,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text('加载失败：\n$_error', textAlign: TextAlign.center))
            : r == null
            ? const Center(child: Text('暂无数据'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Milan · 当前环境',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _InfoRow(
                            label: '温度',
                            value: r.temperatureC?.toStringAsFixed(1),
                            unit: '°C',
                          ),
                          _InfoRow(
                            label: '风速',
                            value: r.windKmh?.toStringAsFixed(1),
                            unit: 'km/h',
                          ),
                          _InfoRow(
                            label: 'PM2.5',
                            value: r.pm25?.toStringAsFixed(1),
                            unit: 'µg/m³',
                          ),
                          _InfoRow(
                            label: 'PM10',
                            value: r.pm10?.toStringAsFixed(1),
                            unit: 'µg/m³',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_run),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '建议：${_suggestion(r)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class WeatherResult {
  final double? temperatureC;
  final double? windKmh;
  final double? pm25;
  final double? pm10;

  WeatherResult({
    required this.temperatureC,
    required this.windKmh,
    required this.pm25,
    required this.pm10,
  });
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final String unit;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '—' : '$value $unit';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Milan center
    final milan = LatLng(45.4642, 9.1900);

    // 一条“示例跑步路线”（后面你们可以换成真实路线规划 API）
    final route = <LatLng>[
      LatLng(45.4642, 9.1900),
      LatLng(45.4680, 9.1950),
      LatLng(45.4705, 9.1895),
      LatLng(45.4665, 9.1845),
      LatLng(45.4642, 9.1900),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: FlutterMap(
        options: MapOptions(initialCenter: milan, initialZoom: 13),
        children: [
          // OpenStreetMap tiles
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.cityzen',
          ),

          // Route polyline
          PolylineLayer(polylines: [Polyline(points: route, strokeWidth: 5)]),

          // Marker
          MarkerLayer(
            markers: [
              Marker(
                point: milan,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _CenterText('Activity\n(Workout log later)');
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Roadmap (Next steps):\n\n'
          '• City selection (Milan / Rome / etc.)\n'
          '• Personalized air-quality thresholds\n'
          '• AI-based activity recommendations\n'
          '• Data visualization & history\n'
          '• Final report & presentation\n',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class _CenterText extends StatelessWidget {
  final String text;
  const _CenterText(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}
