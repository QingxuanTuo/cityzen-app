import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cityzen/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      theme: AppTheme.light(),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeOnce());
  }

  Future<void> _showWelcomeOnce() async {
    final sp = await SharedPreferences.getInstance();
    final seen = sp.getBool('seen_welcome') ?? false;
    if (seen) return;

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to CityZen',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'We use weather + air quality to help you choose the best time for outdoor activities.',
                  style: TextStyle(height: 1.35),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    await sp.setBool('seen_welcome', true);
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
        '&current=temperature_2m,wind_speed_10m,weathercode,relative_humidity_2m'
        '&timezone=auto',
      );
      // ✅ 额外请求：空气质量（pm2_5 / pm10）
      final aqUri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality'
        '?latitude=$lat&longitude=$lon'
        '&hourly=pm10,pm2_5'
        '&timezone=auto',
      );

      final aqResp = await http.get(aqUri).timeout(const Duration(seconds: 10));
      if (aqResp.statusCode != 200) {
        throw Exception('AirQuality HTTP ${aqResp.statusCode}');
      }

      final aqJson = jsonDecode(aqResp.body) as Map<String, dynamic>;
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

      debugPrint('AQ pm2_5=$pm25 pm10=$pm10');

      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      final current = jsonMap['current'] as Map<String, dynamic>?;

      final temp = (current?['temperature_2m'] as num?)?.toDouble();
      final wind = (current?['wind_speed_10m'] as num?)?.toDouble();
      final weatherCode = current?['weathercode'] as int?;
      final humidity = (current?['relative_humidity_2m'] as num?)?.toDouble();

      // PM2.5 / PM10 取 hourly 的第一项（最简单可跑版）
      final hourly = jsonMap['hourly'] as Map<String, dynamic>?;

      final result = WeatherResult(
        temperatureC: temp,
        windKmh: wind,
        weatherCode: weatherCode,
        pm25: pm25,
        pm10: pm10,
        humidity: humidity,
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
    final score = _sportScore(r);
    if (score < 40) return '不建议户外：选择室内训练（瑜伽/力量）更安全。';
    if (score < 60) return '一般：建议短时低强度户外，或选择室内。';

    // final pm25 = r.pm25 ?? 0;
    // final wind = r.windKmh ?? 0;
    // if (pm25 >= 35) return '空气一般：建议室内训练或轻量散步。';
    // if (wind >= 30) return '风有点大：建议骑行注意安全，或选择跑步。';
    return '适合户外运动：可以跑步/骑行。';
  }

  ({IconData icon, String label}) _weatherInfo(int? code) {
    if (code == null) {
      return (icon: Icons.help_outline, label: 'Unknown');
    }

    if (code == 0) {
      return (icon: Icons.wb_sunny, label: 'Clear');
    } else if (code <= 2) {
      return (icon: Icons.wb_cloudy, label: 'Partly Cloudy');
    } else if (code <= 3) {
      return (icon: Icons.cloud, label: 'Overcast');
    } else if (code == 45 || code == 48) {
      return (icon: Icons.foggy, label: 'Fog');
    } else if (code >= 51 && code <= 67) {
      return (icon: Icons.umbrella, label: 'Rain');
    } else if (code >= 71 && code <= 77) {
      return (icon: Icons.ac_unit, label: 'Snow');
    } else {
      return (icon: Icons.cloud, label: 'Unstable');
    }
  }

  ({String label, Color color}) _airQualityTag(double? pm25) {
    if (pm25 == null) return (label: 'Unknown', color: Colors.grey);

    // 这里用 WHO 常见分档的“简化版”（可在报告里解释为 MVP）
    if (pm25 < 10) return (label: 'Good', color: Colors.green);
    if (pm25 < 25) return (label: 'Moderate', color: Colors.amber);
    return (label: 'Poor', color: Colors.red);
  }

  int _sportScore(WeatherResult r) {
    // 0~100，越高越适合户外运动
    double score = 100;

    final pm25 = r.pm25 ?? 0;
    final wind = r.windKmh ?? 0;
    final code = r.weatherCode ?? 0;

    // PM2.5：越高扣分越多
    if (pm25 >= 10) score -= (pm25 - 10) * 1.6; // 10→0 扣，越高扣越多
    // 风：强风扣分
    if (wind >= 15) score -= (wind - 15) * 1.2;

    // 天气：雨雪雾扣分
    final isFog = (code == 45 || code == 48);
    final isRain = (code >= 51 && code <= 67) || (code >= 80 && code <= 82);
    final isSnow = (code >= 71 && code <= 77);
    if (isFog) score -= 15;
    if (isRain) score -= 20;
    if (isSnow) score -= 25;

    score = score.clamp(0, 100);
    return score.round();
  }

  String _scoreText(int score) {
    if (score >= 80) return 'Great for outdoor';
    if (score >= 60) return 'OK with caution';
    if (score >= 40) return 'Better indoor';
    return 'Not recommended';
  }

  Color _pmColor(double? pm25) {
    return _airQualityTag(pm25).color;
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: _loading
            ? const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? Center(child: Text('加载失败：\n$_error', textAlign: TextAlign.center))
            : r == null
            ? const Center(child: Text('暂无数据'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 📍 城市
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Milan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// 🌦️ 环境评估卡片
                  Card(
                    color: const Color(0xFFEEF6DA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          /// 🧠 Outdoor Score
                          Builder(
                            builder: (context) {
                              final s = _sportScore(r);
                              final tag = _airQualityTag(r.pm25);
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Outdoor Score'),
                                  Row(
                                    children: [
                                      Text(
                                        '$s/100',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tag.color.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          _scoreText(s),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: tag.color,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          _InfoRow(
                            label: 'Temperature',
                            value: r.temperatureC?.toStringAsFixed(1),
                            unit: '°C',
                          ),
                          _InfoRow(
                            label: 'Wind',
                            value: r.windKmh?.toStringAsFixed(1),
                            unit: 'km/h',
                          ),

                          /// ☁️ 天气
                          Builder(
                            builder: (context) {
                              final info = _weatherInfo(r.weatherCode);
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Weather'),
                                  Row(
                                    children: [
                                      Icon(
                                        info.icon,
                                        size: 30,
                                        color: const Color.fromARGB(
                                          221,
                                          240,
                                          113,
                                          219,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        info.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),

                          _InfoRow(
                            label: 'Humidity',
                            value: r.humidity?.toStringAsFixed(0),
                            unit: '%',
                          ),

                          const Divider(height: 24),

                          /// 🟢 PM2.5
                          Builder(
                            builder: (context) {
                              final tag = _airQualityTag(r.pm25);
                              final v = r.pm25;
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('PM2.5'),
                                  Row(
                                    children: [
                                      Text(
                                        v == null
                                            ? '—'
                                            : '${v.toStringAsFixed(1)} µg/m³',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tag.color.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: tag.color.withOpacity(0.35),
                                          ),
                                        ),
                                        child: Text(
                                          tag.label,
                                          style: TextStyle(
                                            color: tag.color,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),

                          Builder(
                            builder: (context) {
                              final tag = _airQualityTag(r.pm10);
                              final v = r.pm10;
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('PM10'),
                                  Row(
                                    children: [
                                      Text(
                                        v == null
                                            ? '—'
                                            : '${v.toStringAsFixed(1)} µg/m³',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tag.color.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: tag.color.withOpacity(0.35),
                                          ),
                                        ),
                                        child: Text(
                                          tag.label,
                                          style: TextStyle(
                                            color: tag.color,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 🏃 建议卡片
                  Card(
                    color: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_run, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '建议：${_suggestion(r)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// ⭐ 推荐活动标题
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recommended Activities',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Swipe to see more →'),
                            ),
                          );
                        },
                        child: const Text('See all'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// 🧩 推荐活动列表
                  SizedBox(
                    height: 150,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 16),
                      children: [
                        _ActivityCard(
                          icon: Icons.directions_run,
                          title: 'Running',
                          subtitle: 'Good air quality',
                          backgroundColor: const Color(0xFFEAF6D5),
                        ),
                        _ActivityCard(
                          icon: Icons.pedal_bike,
                          title: 'Cycling',
                          subtitle: 'Low wind',
                          backgroundColor: const Color(0xFFDFF1FC),
                        ),
                        _ActivityCard(
                          icon: Icons.self_improvement,
                          title: 'Yoga',
                          subtitle: 'Indoor option',
                          backgroundColor: const Color(0xFFFFE6EE),
                        ),
                        const SizedBox(width: 12),
                      ],
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
  final int? weatherCode;
  final double? pm25;
  final double? pm10;
  final double? humidity;

  WeatherResult({
    required this.temperatureC,
    required this.windKmh,
    required this.weatherCode,
    required this.pm25,
    required this.pm10,
    required this.humidity,
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

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;

  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: Colors.black),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
