import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cityzen/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cityzen/ai_service.dart';
import 'package:cityzen/environment_data.dart';
import 'package:cityzen/ai_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';

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

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onGoActivity: () => setState(() => _index = 2),
      ), // ✅ 跳到 Activity tab
      const MapPage(),
      const ActivityPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
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
  final VoidCallback? onGoActivity;

  const HomePage({super.key, this.onGoActivity});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = false;
  String? _error;
  WeatherResult? _result;
  final EnvironmentDataManager _envManager = EnvironmentDataManager();

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
                    onPressed: () {
                      Navigator.pop(context); // 先关弹窗
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        widget.onGoActivity?.call(); // 下一帧切 tab
                      });
                    },

                    child: const Text('Get Started >>'),
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

      final result = WeatherResult(
        temperatureC: temp,
        windKmh: wind,
        weatherCode: weatherCode,
        pm25: pm25,
        pm10: pm10,
        humidity: humidity,
      );

      setState(() => _result = result);

      // 同步数据到全局管理器
      _envManager.updateData(EnvironmentData.fromWeatherResult(result));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _suggestion(WeatherResult r) {
    final score = _sportScore(r);
    if (score < 40) return 'Get started!';
    if (score < 60) return 'Get started!';
    return '';
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

  // ✅ 右上角装饰 PNG：根据天气切换（你只有 2 张图，所以先做最小映射）
  String _weatherDecorAsset(int? code) {
    if (code == null) return 'lib/assets/weather/cloudy.png';
    if (code == 0) return 'lib/assets/weather/sunny.png';
    if (code <= 3) return 'lib/assets/weather/cloudy.png';
    return 'lib/assets/weather/cloudy.png';
  }

  ({String label, Color color}) _airQualityTag(double? pm25) {
    if (pm25 == null) return (label: 'No data', color: Colors.grey);

    // EAQI bands for PM2.5 (µg/m³): 0-5, 6-15, 16-50, 51-90, 91-140, >140
    if (pm25 <= 5) return (label: 'Good', color: Colors.green);
    if (pm25 <= 15) return (label: 'Fair', color: Colors.lightGreen);
    if (pm25 <= 50) return (label: 'Moderate', color: Colors.amber);
    if (pm25 <= 90) return (label: 'Poor', color: Colors.orange);
    if (pm25 <= 140) return (label: 'Very poor', color: Colors.red);
    return (label: 'Extremely poor', color: Colors.purple);
  }

  String _eaqiAdvice(String eaqiLabel) {
    switch (eaqiLabel) {
      case 'Good':
      case 'Fair':
        return 'Great day for outdoor workouts.';
      case 'Moderate':
        return 'Outdoor OK, avoid peak traffic hours.';
      case 'Poor':
      case 'Very poor':
      case 'Extremely poor':
        return 'Prefer indoor activities today.';
      default:
        return 'Refresh to get current air quality advice.';
    }
  }

  int _sportScore(WeatherResult r) {
    double score = 100;

    final pm25 = r.pm25 ?? 0;
    final wind = r.windKmh ?? 0;
    final code = r.weatherCode ?? 0;

    if (pm25 >= 10) score -= (pm25 - 10) * 1.6;
    if (wind >= 15) score -= (wind - 15) * 1.2;

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
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'CityZen',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Colors.black,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchWeather,
          ),
        ],

        // ✅ AppBar 下方加“定位 pill”，像你参考图那样
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Colors.black.withOpacity(0.75),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Milan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
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
                  // ✅ 顶部 Header：定位 + 问候 + 日期 + 时间（参考图布局）
                  const SizedBox(height: 0),
                  _HeaderTop(city: 'Milan'),
                  const SizedBox(height: 14),

                  /// 🌦️ 环境评估卡片
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.none, // ✅ 允许溢出（半进半出）
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFDFF1FC), // 蓝
                            Color(0xFFBFDFA3), // 稍深的绿
                          ],
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none, // ✅ 允许 Stack 子组件溢出
                        children: [
                          // ✅ 原内容
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const SizedBox(height: 0),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ✅ 左侧：温度 + 描述（改成 Column）
                                    Expanded(
                                      child: Align(
                                        alignment:
                                            Alignment.centerLeft, // ✅ 强制整组贴左
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment
                                              .start, // ✅ 文本左对齐
                                          children: [
                                            Text(
                                              r.temperatureC == null
                                                  ? '—'
                                                  : '${r.temperatureC!.toStringAsFixed(1)} °C',
                                              textAlign: TextAlign
                                                  .left, // ✅ 确保不是 center
                                              style: const TextStyle(
                                                fontSize: 44,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _weatherInfo(r.weatherCode).label,
                                              textAlign: TextAlign
                                                  .left, // ✅ 确保不是 center
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                height: 1.0,
                                                color: Colors.black.withOpacity(
                                                  0.7,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // ✅ 右侧：保持空位给装饰图（如果你右上角有 PNG 溢出，这里可以留一点宽度）
                                    const SizedBox(width: 10),

                                    // 右：图片区域（你原来这个 Column 没内容就别占位了）
                                    // 如果你不需要任何右侧文字，把它删掉即可
                                  ],
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _MiniStatCard(
                                        title: 'Wind',
                                        value: r.windKmh == null
                                            ? '—'
                                            : r.windKmh!.toStringAsFixed(1),
                                        unit: 'km/h',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MiniStatCard(
                                        title: 'Humidity',
                                        value: r.humidity == null
                                            ? '—'
                                            : r.humidity!.toStringAsFixed(0),
                                        unit: '%',
                                        background: const Color(0xFFD9F0A7),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final pmTag = _airQualityTag(r.pm25);
                                          return _MiniStatCard(
                                            title: 'PM2.5',
                                            value: r.pm25 == null
                                                ? '—'
                                                : r.pm25!.toStringAsFixed(1),
                                            unit: 'µg/m³',
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ✅ 右上角装饰 PNG（半进半出）
                          Positioned(
                            right: -36,
                            top: -46,
                            child: IgnorePointer(
                              ignoring: true,
                              child: Opacity(
                                opacity: 01.00,
                                child: Image.asset(
                                  _weatherDecorAsset(r.weatherCode),
                                  width: 230,
                                  height: 175,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ✅ EAQI 总览卡片（新加）
                  Builder(
                    builder: (context) {
                      final tag = _airQualityTag(r.pm25);
                      return _EAQICard(
                        pm25: r.pm25,
                        eaqiLabel: tag.label,
                        eaqiColor: tag.color,
                        advice: _eaqiAdvice(tag.label),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  /// 🏃 Get started 卡片（可点击跳转到 Activity）
                  Card(
                    color: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: widget.onGoActivity, // ✅ 点这里切到 Activity tab
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.directions_run,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Get started >>',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}

/// ✅ 改好的 MiniStatCard：
/// - 不再用 FittedBox 缩整行（防止 PM2.5 看起来更小）
/// - 数字大、单位小（视觉统一）
/// - badge 有最小宽高（不会“缩成一小坨”）
class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Color? background;

  final String? badgeText;
  final Color? badgeColor;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.unit,
    this.background,
    this.badgeText,
    this.badgeColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: background ?? Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 10),

              // ✅ 数字大、单位小，字号统一
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '',
                      style: TextStyle(), // 占位，避免某些主题 null 报警
                    ),
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Inter',
                        letterSpacing: -0.4,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // ✅ 右上角标签（最小宽高 + 稳定 pill）
        if (badgeText != null && badgeText!.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 64),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: (badgeColor ?? Colors.black).withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: (badgeColor ?? Colors.black).withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor ?? Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AirQualityTrend extends StatelessWidget {
  final List<double> values;
  final Color color;

  const AirQualityTrend({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox(height: 50);

    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return SizedBox(
      height: 110,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),

          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 25, // 底部留一点高度
                interval: 1,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9AA0A6),
                  );

                  final i = value.round();

                  // 12 个点（每 2 小时一个点）
                  // 0  1  2  3  4  5  6  7  8  9 10 11
                  // 00 02 04 06 08 10 12 14 16 18 20 22
                  String? label;
                  switch (i) {
                    case 0:
                      label = '00';
                      break;
                    case 2:
                      label = '04';
                      break;
                    case 4:
                      label = '08';
                      break;
                    case 6:
                      label = '12';
                      break;
                    case 8:
                      label = '16';
                      break;
                    case 10:
                      label = '20';
                      break;
                  }

                  if (label == null) return const SizedBox.shrink();

                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(label, style: style),
                  );
                },
              ),
            ),
          ),

          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 2.5,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6CB8FF), // 蓝（接近你天气卡片的 sky）
                  Color(0xFF86BE24), // 绿（CityZen 主色）
                ],
              ),

              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final String unit;
  final bool highlight;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.unit,
    this.highlight = false,
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
          Text(
            text,
            style: TextStyle(
              fontSize: highlight ? 36 : 14,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderTop extends StatelessWidget {
  final String city;

  const _HeaderTop({required this.city, super.key});

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good Morning!';
    if (h < 18) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  String _weekday(DateTime now) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[now.weekday - 1];
  }

  String _month(DateTime now) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[now.month - 1];
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = _greeting(now);
    final dateLine = '${_weekday(now)}, ${now.day} ${_month(now)} ${now.year}';
    final timeLine = '${_two(now.hour)}:${_two(now.minute)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 问候 + 日期（左）  时间（右）
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateLine,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 右侧大时间
            Text(
              timeLine,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EAQICard extends StatelessWidget {
  final double? pm25;
  final String eaqiLabel;
  final Color eaqiColor;
  final String advice;

  const _EAQICard({
    required this.pm25,
    required this.eaqiLabel,
    required this.eaqiColor,
    required this.advice,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：标题 + pill
            Row(
              children: [
                // 小色点（轻量表达状态）
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: eaqiColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),

                const Text(
                  'Air Quality (EAQI)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),

                const Spacer(),

                // 右侧状态 pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: eaqiColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: eaqiColor.withOpacity(0.20)),
                  ),
                  child: Text(
                    eaqiLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: eaqiColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 第二行：建议（主文案）
            Text(
              advice,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E2E2E),
              ),
            ),
            const SizedBox(height: 20),

            // 小趋势图（示例数据：12个点=一天趋势）
            AirQualityTrend(
              values: const [18, 22, 20, 28, 35, 40, 52, 60, 58, 55, 50, 44],
              color: eaqiColor,
            ),
          ],
        ),
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _mapController = MapController();
  String _selectedLayer = 'AQI';

  final _milan = LatLng(45.4642, 9.1900);
  // 当前“中心数据/标记”的位置，初始为米兰
  late LatLng _center = _milan;
  GridPoint? _centerData;
  bool _loading = false;
  String? _error;
  double _currentZoom = 13.0;
  LatLng _currentCenter = const LatLng(45.4642, 9.1900);

  @override
  void initState() {
    super.initState();
    _fetchCenterData();
  }

  Future<void> _fetchCenterData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _fetchPointData(_center);
      setState(() {
        _centerData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // 中心点着色：依据当前图层与中心数据
  Color _centerColor() {
    final d = _centerData;
    if (d == null) return Colors.grey;

    switch (_selectedLayer) {
      case 'AQI':
        final aqi = d.aqi;
        if (aqi == null) return Colors.grey;
        if (aqi <= 50) return Colors.green;
        if (aqi <= 100) return Colors.yellow;
        if (aqi <= 150) return Colors.orange;
        return Colors.red;

      case 'PM2.5':
        final pm25 = d.pm25;
        if (pm25 == null) return Colors.grey;
        if (pm25 < 10) return Colors.green;
        if (pm25 < 25) return Colors.amber;
        return Colors.red;

      case 'O₃':
        final ozone = d.ozone;
        if (ozone == null) return Colors.grey;
        if (ozone <= 60) return Colors.green;
        if (ozone <= 120) return Colors.yellow;
        if (ozone <= 180) return Colors.orange;
        return Colors.red;

      case 'Rain':
        final precip = d.precipitation;
        if (precip == null) return Colors.grey;
        if (precip == 0) return Colors.grey[300]!;
        if (precip < 5) return Colors.lightBlue[200]!;
        if (precip < 20) return Colors.blue;
        return Colors.indigo;

      default:
        return Colors.grey;
    }
  }

  Future<GridPoint> _fetchPointData(LatLng point) async {
    try {
      // 天气数据
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${point.latitude}&longitude=${point.longitude}'
        '&current=temperature_2m,precipitation,weathercode'
        '&timezone=auto',
      );

      // 空气质量数据
      final aqUri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality'
        '?latitude=${point.latitude}&longitude=${point.longitude}'
        '&current=pm2_5,pm10,ozone'
        '&timezone=auto',
      );

      final weatherResp = await http
          .get(weatherUri)
          .timeout(const Duration(seconds: 10));
      final aqResp = await http.get(aqUri).timeout(const Duration(seconds: 10));

      if (weatherResp.statusCode != 200 || aqResp.statusCode != 200) {
        throw Exception('API request failed');
      }

      final weatherJson = jsonDecode(weatherResp.body) as Map<String, dynamic>;
      final aqJson = jsonDecode(aqResp.body) as Map<String, dynamic>;

      final weatherCurrent = weatherJson['current'] as Map<String, dynamic>?;
      final aqCurrent = aqJson['current'] as Map<String, dynamic>?;

      final temp = (weatherCurrent?['temperature_2m'] as num?)?.toDouble();
      final precip = (weatherCurrent?['precipitation'] as num?)?.toDouble();
      final weatherCode = weatherCurrent?['weathercode'] as int?;

      final pm25 = (aqCurrent?['pm2_5'] as num?)?.toDouble();
      final pm10 = (aqCurrent?['pm10'] as num?)?.toDouble();
      final ozone = (aqCurrent?['ozone'] as num?)?.toDouble();

      // 简化版AQI计算（基于PM2.5）
      final aqi = _calculateAQI(pm25);

      return GridPoint(
        location: point,
        temperature: temp,
        precipitation: precip,
        pm25: pm25,
        pm10: pm10,
        ozone: ozone,
        aqi: aqi,
        weatherCode: weatherCode,
      );
    } catch (e) {
      // 失败时返回空数据点
      return GridPoint(location: point);
    }
  }

  int? _calculateAQI(double? pm25) {
    if (pm25 == null) return null;
    // 简化版 AQI 计算（美国EPA标准）
    if (pm25 <= 12) return (pm25 / 12 * 50).round();
    if (pm25 <= 35.4) return (50 + (pm25 - 12) / 23.4 * 50).round();
    if (pm25 <= 55.4) return (100 + (pm25 - 35.4) / 20 * 50).round();
    if (pm25 <= 150.4) return (150 + (pm25 - 55.4) / 95 * 50).round();
    return 200;
  }

  void _recenterMap() {
    _mapController.move(_center, 13);
  }

  void _recenterToDefault() {
    if (!mounted) return;
    setState(() {
      _center = _milan;
      _currentCenter = _milan;
    });
    _mapController.move(_milan, 13);
    _fetchCenterData();
  }

  Future<void> _recenterToMyLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _recenterToDefault();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _recenterToDefault();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userCenter = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _center = userCenter;
        _currentCenter = userCenter;
      });
      _mapController.move(userCenter, _currentZoom);
      await _fetchCenterData();
    } catch (_) {
      _recenterToDefault();
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    // 仅在点击接近中心点时显示详情
    const thresholdDeg = 0.0004; // ~40-50米的经纬度粗略阈值
    final dist2 = _distanceSquared(point, _center);
    if (dist2 > thresholdDeg * thresholdDeg) {
      return; // 点击其他区域不显示
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildBottomSheet(point, _centerData),
    );
  }

  double _distanceSquared(LatLng a, LatLng b) {
    final dx = a.latitude - b.latitude;
    final dy = a.longitude - b.longitude;
    return dx * dx + dy * dy;
  }

  Widget _buildBottomSheet(LatLng point, GridPoint? data) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Coordinates',
            value:
                '${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)}',
          ),
          if (data != null) ...[
            _DetailRow(
              label: 'AQI',
              value: data.aqi != null ? '${data.aqi}' : 'N/A',
            ),
            _DetailRow(
              label: 'PM2.5',
              value: data.pm25 != null
                  ? '${data.pm25!.toStringAsFixed(1)} µg/m³'
                  : 'N/A',
            ),
            _DetailRow(
              label: 'O₃',
              value: data.ozone != null
                  ? '${data.ozone!.toStringAsFixed(1)} µg/m³'
                  : 'N/A',
            ),
            _DetailRow(
              label: 'Temperature',
              value: data.temperature != null
                  ? '${data.temperature!.toStringAsFixed(1)}°C'
                  : 'N/A',
            ),
            _DetailRow(
              label: 'Precipitation',
              value: data.precipitation != null
                  ? '${data.precipitation!.toStringAsFixed(1)} mm'
                  : 'N/A',
            ),
          ] else
            const Text(
              'Loading data...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // 不再着色网格点：仅保留中心点数据

  @override
  Widget build(BuildContext context) {
    final route = <LatLng>[
      LatLng(45.4642, 9.1900),
      LatLng(45.4680, 9.1950),
      LatLng(45.4705, 9.1895),
      LatLng(45.4665, 9.1845),
      LatLng(45.4642, 9.1900),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchCenterData,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 地图主体
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.drag |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom,
              ),
              onTap: _onMapTap,
              onPositionChanged: (position, _) {
                final z = position.zoom;
                final c = position.center;
                if (z != null) _currentZoom = z;
                if (c != null) _currentCenter = c;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.cityzen',
              ),
              PolylineLayer(
                polylines: [Polyline(points: route, strokeWidth: 5)],
              ),
              // 仅显示中心点（米兰）
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 24,
                    height: 24,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _centerColor(),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 加载指示器
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading environmental data...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 错误提示
          if (_error != null && !_loading)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Error: $_error',
                    style: TextStyle(color: Colors.red[900]),
                  ),
                ),
              ),
            ),

          // 顶部：图层切换
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _LayerSelector(
              selectedLayer: _selectedLayer,
              onLayerChanged: (layer) => setState(() => _selectedLayer = layer),
            ),
          ),

          // 右下：定位按钮
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'recenter',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _recenterToMyLocation,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // 右下：缩放按钮
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
              ],
            ),
          ),

          // 左下：图例
          Positioned(
            bottom: 16,
            left: 16,
            child: _MapLegend(layerType: _selectedLayer),
          ),
        ],
      ),
    );
  }

  void _zoomIn() {
    final nextZoom = (_currentZoom + 1).clamp(3.0, 18.0);
    _mapController.move(_currentCenter, nextZoom);
  }

  void _zoomOut() {
    final nextZoom = (_currentZoom - 1).clamp(3.0, 18.0);
    _mapController.move(_currentCenter, nextZoom);
  }
}

// 图层选择器
class _LayerSelector extends StatelessWidget {
  final String selectedLayer;
  final ValueChanged<String> onLayerChanged;

  const _LayerSelector({
    required this.selectedLayer,
    required this.onLayerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final layers = ['AQI', 'PM2.5', 'O₃', 'Rain'];

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: layers.map((layer) {
          final isSelected = layer == selectedLayer;
          return Expanded(
            child: GestureDetector(
              onTap: () => onLayerChanged(layer),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  layer,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 地图图例
class _MapLegend extends StatelessWidget {
  final String layerType;

  const _MapLegend({required this.layerType});

  @override
  Widget build(BuildContext context) {
    final legend = _getLegendData(layerType);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            legend.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...legend.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(item.label, style: const TextStyle(fontSize: 11)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  ({String title, List<({Color color, String label})> items}) _getLegendData(
    String layer,
  ) {
    switch (layer) {
      case 'AQI':
        return (
          title: 'AQI Index',
          items: [
            (color: Colors.green, label: 'Good (0-50)'),
            (color: Colors.yellow, label: 'Moderate (51-100)'),
            (color: Colors.orange, label: 'Unhealthy (101-150)'),
            (color: Colors.red, label: 'Very Unhealthy (151+)'),
          ],
        );
      case 'PM2.5':
        return (
          title: 'PM2.5 (µg/m³)',
          items: [
            (color: Colors.green, label: 'Good (0-10)'),
            (color: Colors.amber, label: 'Moderate (10-25)'),
            (color: Colors.red, label: 'Poor (25+)'),
          ],
        );
      case 'O₃':
        return (
          title: 'Ozone (O₃) µg/m³',
          items: [
            (color: Colors.green, label: 'Good (0-60)'),
            (color: Colors.yellow, label: 'Moderate (61-120)'),
            (color: Colors.orange, label: 'Unhealthy (121-180)'),
            (color: Colors.red, label: 'Very Unhealthy (181+)'),
          ],
        );
      case 'Rain':
        return (
          title: 'Precipitation (mm)',
          items: [
            (color: Colors.grey[300]!, label: 'None (0)'),
            (color: Colors.lightBlue[200]!, label: 'Light (0-5)'),
            (color: Colors.blue, label: 'Moderate (5-20)'),
            (color: Colors.indigo, label: 'Heavy (20+)'),
          ],
        );
      default:
        return (title: 'Unknown', items: []);
    }
  }
}

// Bottom Sheet 详情行
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _isWorkoutActive = false;
  String _activeWorkoutType = '';
  DateTime? _workoutStartTime;
  List<WorkoutSession> _recentSessions = [];
  bool _showAIChat = false;
  final TextEditingController _chatController = TextEditingController();
  final List<ChatMessage> _chatMessages = [];
  late final GeminiAIService _aiService;
  bool _isAILoading = false;
  final EnvironmentDataManager _envManager = EnvironmentDataManager();

  // 当前环境数据（从全局管理器获取）
  EnvironmentData? get _currentEnvironmentData => _envManager.currentData;

  @override
  void initState() {
    super.initState();
    _aiService = GeminiAIService();
    _loadRecentSessions();
    _addWelcomeMessage();

    // 监听环境数据变化
    _envManager.addListener(_onEnvironmentDataChanged);

    // 刷新AI配置
    _refreshAIService();
  }

  Future<void> _refreshAIService() async {
    await _aiService.refreshConfig();
  }

  @override
  void dispose() {
    _envManager.removeListener(_onEnvironmentDataChanged);
    super.dispose();
  }

  void _onEnvironmentDataChanged() {
    if (mounted) {
      setState(() {
        // 环境数据更新时刷新UI
      });
    }
  }

  void _addWelcomeMessage() {
    _chatMessages.add(
      ChatMessage(
        text:
            "Hi! I'm your AI fitness coach powered by Google Gemini. I analyze real-time environmental data to give you personalized workout recommendations. What would you like to know about exercising today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _loadRecentSessions() async {
    // 模拟加载历史数据
    setState(() {
      _recentSessions = [
        WorkoutSession(
          id: '1',
          type: 'Running',
          date: DateTime.now().subtract(const Duration(days: 1)),
          duration: const Duration(minutes: 30),
          distance: 5.2,
          environmentScore: 85,
        ),
        WorkoutSession(
          id: '2',
          type: 'Cycling',
          date: DateTime.now().subtract(const Duration(days: 3)),
          duration: const Duration(minutes: 45),
          distance: 12.8,
          environmentScore: 72,
        ),
        WorkoutSession(
          id: '3',
          type: 'Yoga',
          date: DateTime.now().subtract(const Duration(days: 5)),
          duration: const Duration(minutes: 60),
          distance: 0,
          environmentScore: 90,
        ),
      ];
    });
  }

  void _startWorkout(String type) {
    setState(() {
      _isWorkoutActive = true;
      _activeWorkoutType = type;
      _workoutStartTime = DateTime.now();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Started $type workout!'),
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'Stop',
          textColor: Colors.white,
          onPressed: _stopWorkout,
        ),
      ),
    );
  }

  void _stopWorkout() {
    if (_workoutStartTime != null) {
      final duration = DateTime.now().difference(_workoutStartTime!);
      setState(() {
        _isWorkoutActive = false;
        _recentSessions.insert(
          0,
          WorkoutSession(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: _activeWorkoutType,
            date: _workoutStartTime!,
            duration: duration,
            distance: 2.5, // 模拟数据
            environmentScore: 78,
          ),
        );
        _activeWorkoutType = '';
        _workoutStartTime = null;
      });
    }
  }

  Future<void> _sendChatMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _chatMessages.add(
        ChatMessage(text: message, isUser: true, timestamp: DateTime.now()),
      );
      _isAILoading = true;
    });

    _chatController.clear();

    try {
      final envData = _currentEnvironmentData;

      // 使用真实的环境数据或提示用户刷新
      if (envData == null || _envManager.isDataStale) {
        setState(() {
          _chatMessages.add(
            ChatMessage(
              text:
                  "I notice the environmental data might be outdated. Please go to the Home page and refresh the data for the most accurate recommendations.",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isAILoading = false;
        });
        return;
      }

      // 使用真实的Gemini AI服务
      final aiResponse = await _aiService.getWorkoutAdvice(
        userMessage: message,
        pm25: envData.pm25,
        pm10: envData.pm10,
        windSpeed: envData.windKmh,
        temperature: envData.temperatureC,
        weatherCode: envData.weatherCode,
        city: 'Milan',
      );

      setState(() {
        _chatMessages.add(
          ChatMessage(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isAILoading = false;
      });
    } catch (e) {
      setState(() {
        _chatMessages.add(
          ChatMessage(
            text:
                "Sorry, I'm having trouble connecting right now. Please try again in a moment.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isAILoading = false;
      });
    }
  }

  String _generateAIResponse(String userMessage) {
    final message = userMessage.toLowerCase();

    if (message.contains('weather') || message.contains('air quality')) {
      return "Based on current conditions (PM2.5: 75 µg/m³), I'd recommend indoor activities like yoga or light stretching. The air quality is moderate today, so if you do go outside, consider shorter, less intense workouts.";
    } else if (message.contains('running') || message.contains('run')) {
      return "For running today, I suggest early morning (6-8 AM) when air quality is typically better. Keep your pace moderate and consider a shorter route. Would you like me to suggest a specific route based on current wind patterns?";
    } else if (message.contains('cycling') || message.contains('bike')) {
      return "Cycling could work today, but avoid busy roads due to air quality. I recommend park routes or bike paths. The wind speed is moderate, so you might face some resistance heading north.";
    } else if (message.contains('yoga') || message.contains('indoor')) {
      return "Perfect choice! Indoor yoga is ideal for today's conditions. I can guide you through a 30-minute session focused on breathing exercises, which is great when outdoor air quality isn't optimal.";
    } else if (message.contains('plan') || message.contains('schedule')) {
      return "Based on your activity history and this week's forecast, I suggest: Monday/Wednesday - Indoor yoga, Tuesday/Thursday - Early morning runs, Friday - Cycling in the park. This balances your fitness goals with environmental conditions.";
    } else {
      return "I'm here to help you make smart fitness decisions based on environmental data. You can ask me about workout recommendations, timing, or how weather affects different activities. What specific activity are you considering?";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: Icon(_showAIChat ? Icons.close : Icons.smart_toy),
            onPressed: () => setState(() => _showAIChat = !_showAIChat),
          ),
        ],
      ),
      body: _showAIChat ? _buildAIChat() : _buildMainContent(),
      floatingActionButton: _isWorkoutActive
          ? FloatingActionButton.extended(
              onPressed: _stopWorkout,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.stop),
              label: Text('Stop ${_activeWorkoutType}'),
            )
          : null,
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 今日状态卡片
          _buildTodayStatusCard(),

          const SizedBox(height: 20),

          // 快速开始运动
          _buildQuickStartSection(),

          const SizedBox(height: 24),

          // AI推荐
          _buildAIRecommendationCard(),

          const SizedBox(height: 24),

          // 最近活动
          _buildRecentActivitiesSection(),

          const SizedBox(height: 24),

          // 统计概览
          _buildStatsOverview(),
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.1), AppColors.sky],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    'Steps',
                    '8,432',
                    Icons.directions_walk,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    'Calories',
                    '342',
                    Icons.local_fire_department,
                  ),
                ),
                Expanded(child: _buildStatusItem('Time', '45m', Icons.timer)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildQuickStartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Start',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickStartCard(
                'Running',
                Icons.directions_run,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickStartCard(
                'Cycling',
                Icons.pedal_bike,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickStartCard(
                'Yoga',
                Icons.self_improvement,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStartCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _startWorkout(title),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendationCard() {
    final envData = _currentEnvironmentData;
    String recommendationText = "Loading environmental data...";

    if (envData == null) {
      recommendationText =
          "Environmental data not available. Please refresh data on the Home page to get personalized recommendations.";
    } else if (_envManager.isDataStale) {
      recommendationText =
          "Environmental data is outdated. Please refresh on the Home page for current recommendations.";
    } else {
      final pm25 = envData.pm25;
      if (pm25 != null) {
        if (pm25 > 50) {
          recommendationText =
              "Poor air quality today (PM2.5: ${pm25.toStringAsFixed(1)} µg/m³). Indoor activities strongly recommended for your safety.";
        } else if (pm25 > 25) {
          recommendationText =
              "Moderate air quality today (PM2.5: ${pm25.toStringAsFixed(1)} µg/m³). Consider shorter outdoor sessions or indoor alternatives.";
        } else if (pm25 > 10) {
          recommendationText =
              "Good air quality today (PM2.5: ${pm25.toStringAsFixed(1)} µg/m³). Outdoor activities are recommended, but avoid peak traffic hours.";
        } else {
          recommendationText =
              "Excellent air quality today (PM2.5: ${pm25.toStringAsFixed(1)} µg/m³)! Perfect conditions for any outdoor activity.";
        }

        // 添加温度信息
        if (envData.temperatureC != null) {
          final temp = envData.temperatureC!;
          if (temp < 5) {
            recommendationText +=
                " Cold weather (${temp.toStringAsFixed(1)}°C) - dress warmly and warm up thoroughly.";
          } else if (temp > 25) {
            recommendationText +=
                " Warm weather (${temp.toStringAsFixed(1)}°C) - stay hydrated and avoid peak sun hours.";
          } else {
            recommendationText +=
                " Comfortable temperature (${temp.toStringAsFixed(1)}°C) for outdoor activities.";
          }
        }
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.orange.withOpacity(0.1),
              Colors.pink.withOpacity(0.1),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'AI Coach Recommendation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Gemini 3.0',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(recommendationText, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showAIChat = true),
                icon: const Icon(Icons.chat),
                label: const Text('Chat with AI Coach'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange[700],
                  side: BorderSide(color: Colors.orange[700]!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            TextButton(onPressed: () {}, child: const Text('View All')),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentSessions
            .take(3)
            .map((session) => _buildActivityTile(session)),
      ],
    );
  }

  Widget _buildActivityTile(WorkoutSession session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getActivityColor(session.type).withOpacity(0.1),
          child: Icon(
            _getActivityIcon(session.type),
            color: _getActivityColor(session.type),
          ),
        ),
        title: Text(session.type),
        subtitle: Text(
          '${session.duration.inMinutes}min • ${session.distance.toStringAsFixed(1)}km',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${session.environmentScore}/100',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Env Score',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Workouts', '5', Icons.fitness_center),
                ),
                Expanded(
                  child: _buildStatItem('Total Time', '3h 45m', Icons.schedule),
                ),
                Expanded(
                  child: _buildStatItem('Distance', '28.5km', Icons.straighten),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildAIChat() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            reverse: false, // 改为正序显示
            itemCount: _chatMessages.length + (_isAILoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _chatMessages.length && _isAILoading) {
                return _buildLoadingBubble();
              }
              final message = _chatMessages[index];
              return _buildChatBubble(message);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 环境数据显示
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _currentEnvironmentData != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildEnvDataChip(
                            'PM2.5',
                            '${_currentEnvironmentData!.pm25?.toStringAsFixed(1) ?? '--'}',
                          ),
                          _buildEnvDataChip(
                            'Wind',
                            '${_currentEnvironmentData!.windKmh?.toStringAsFixed(1) ?? '--'} km/h',
                          ),
                          _buildEnvDataChip(
                            'Temp',
                            '${_currentEnvironmentData!.temperatureC?.toStringAsFixed(1) ?? '--'}°C',
                          ),
                        ],
                      )
                    : const Text(
                        'Environmental data not available. Please refresh on Home page.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      decoration: InputDecoration(
                        hintText: 'Ask your AI coach...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _isAILoading ? null : _sendChatMessage,
                      enabled: !_isAILoading,
                      maxLines: null, // 允许多行输入
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    onPressed: _isAILoading
                        ? null
                        : () => _sendChatMessage(_chatController.text),
                    child: _isAILoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnvDataChip(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'AI is thinking...',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
          minHeight: 40,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            height: 1.4,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'Running':
        return AppColors.primary;
      case 'Cycling':
        return Colors.blue;
      case 'Yoga':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Running':
        return Icons.directions_run;
      case 'Cycling':
        return Icons.pedal_bike;
      case 'Yoga':
        return Icons.self_improvement;
      default:
        return Icons.fitness_center;
    }
  }
}

class WorkoutSession {
  final String id;
  final String type;
  final DateTime date;
  final Duration duration;
  final double distance;
  final int environmentScore;

  WorkoutSession({
    required this.id,
    required this.type,
    required this.date,
    required this.duration,
    required this.distance,
    required this.environmentScore,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoRefresh = true;
  String _selectedCity = 'Milan';
  String _temperatureUnit = 'Celsius';
  String _distanceUnit = 'Kilometers';
  double _airQualityThreshold = 25.0;
  double _windSpeedThreshold = 15.0;

  final List<String> _cities = ['Milan', 'Rome', 'Florence', 'Naples', 'Turin'];
  final List<String> _temperatureUnits = ['Celsius', 'Fahrenheit'];
  final List<String> _distanceUnits = ['Kilometers', 'Miles'];

  // AI配置相关
  final AIConfigManager _aiConfigManager = AIConfigManager();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAIConfig();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customModelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadAIConfig() async {
    await _aiConfigManager.loadConfig();
    setState(() {
      _apiKeyController.text = _aiConfigManager.apiKey;
      _customModelController.text = _aiConfigManager.model;
      _baseUrlController.text = _aiConfigManager.baseUrl;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _locationEnabled = prefs.getBool('location_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _autoRefresh = prefs.getBool('auto_refresh') ?? true;
      _selectedCity = prefs.getString('selected_city') ?? 'Milan';
      _temperatureUnit = prefs.getString('temperature_unit') ?? 'Celsius';
      _distanceUnit = prefs.getString('distance_unit') ?? 'Kilometers';
      _airQualityThreshold = prefs.getDouble('air_quality_threshold') ?? 25.0;
      _windSpeedThreshold = prefs.getDouble('wind_speed_threshold') ?? 15.0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('location_enabled', _locationEnabled);
    await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
    await prefs.setBool('auto_refresh', _autoRefresh);
    await prefs.setString('selected_city', _selectedCity);
    await prefs.setString('temperature_unit', _temperatureUnit);
    await prefs.setString('distance_unit', _distanceUnit);
    await prefs.setDouble('air_quality_threshold', _airQualityThreshold);
    await prefs.setDouble('wind_speed_threshold', _windSpeedThreshold);
  }

  void _showCitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Select City',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ..._cities.map(
              (city) => ListTile(
                title: Text(city),
                trailing: _selectedCity == city
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedCity = city);
                  _saveSettings();
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showThresholdDialog(String type) {
    final isAirQuality = type == 'air_quality';
    final currentValue = isAirQuality
        ? _airQualityThreshold
        : _windSpeedThreshold;
    final controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Set ${isAirQuality ? 'Air Quality' : 'Wind Speed'} Threshold',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isAirQuality ? 'PM2.5 (µg/m³)' : 'Wind Speed (km/h)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isAirQuality
                  ? 'Activities will be marked as risky above this PM2.5 level'
                  : 'Activities will be marked as risky above this wind speed',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                setState(() {
                  if (isAirQuality) {
                    _airQualityThreshold = value;
                  } else {
                    _windSpeedThreshold = value;
                  }
                });
                _saveSettings();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _SettingsSection(
              title: 'Profile',
              children: [
                _SettingsCard(
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CityZen User',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Health & Fitness Enthusiast',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ],
            ),

            // Location & Data Section
            _SettingsSection(
              title: 'Location & Data',
              children: [
                _SettingsTile(
                  icon: Icons.location_city,
                  title: 'City',
                  subtitle: _selectedCity,
                  onTap: _showCitySelector,
                ),
                _SettingsTile(
                  icon: Icons.my_location,
                  title: 'Location Services',
                  subtitle: _locationEnabled ? 'Enabled' : 'Disabled',
                  trailing: Switch(
                    value: _locationEnabled,
                    onChanged: (value) {
                      setState(() => _locationEnabled = value);
                      _saveSettings();
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.refresh,
                  title: 'Auto Refresh Data',
                  subtitle: _autoRefresh ? 'Every 30 minutes' : 'Manual only',
                  trailing: Switch(
                    value: _autoRefresh,
                    onChanged: (value) {
                      setState(() => _autoRefresh = value);
                      _saveSettings();
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
              ],
            ),

            // Units & Preferences Section
            _SettingsSection(
              title: 'Units & Preferences',
              children: [
                _SettingsTile(
                  icon: Icons.thermostat,
                  title: 'Temperature Unit',
                  subtitle: _temperatureUnit,
                  onTap: () => _showUnitSelector('temperature'),
                ),
                _SettingsTile(
                  icon: Icons.straighten,
                  title: 'Distance Unit',
                  subtitle: _distanceUnit,
                  onTap: () => _showUnitSelector('distance'),
                ),
              ],
            ),

            // Health Thresholds Section
            _SettingsSection(
              title: 'Health Thresholds',
              children: [
                _SettingsTile(
                  icon: Icons.air,
                  title: 'Air Quality Threshold',
                  subtitle:
                      '${_airQualityThreshold.toStringAsFixed(1)} µg/m³ PM2.5',
                  onTap: () => _showThresholdDialog('air_quality'),
                ),
                _SettingsTile(
                  icon: Icons.air,
                  title: 'Wind Speed Threshold',
                  subtitle: '${_windSpeedThreshold.toStringAsFixed(1)} km/h',
                  onTap: () => _showThresholdDialog('wind_speed'),
                ),
              ],
            ),

            // Notifications Section
            _SettingsSection(
              title: 'Notifications',
              children: [
                _SettingsTile(
                  icon: Icons.notifications,
                  title: 'Push Notifications',
                  subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() => _notificationsEnabled = value);
                      _saveSettings();
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.schedule,
                  title: 'Daily Recommendations',
                  subtitle: 'Get AI-powered activity suggestions',
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {},
                    activeColor: AppColors.primary,
                  ),
                ),
              ],
            ),

            // AI Configuration Section
            _SettingsSection(
              title: 'AI Configuration',
              children: [
                _SettingsTile(
                  icon: Icons.smart_toy,
                  title: 'AI Provider',
                  subtitle: _aiConfigManager.currentProvider.displayName,
                  onTap: () => _showAIProviderSelector(),
                ),
                _SettingsTile(
                  icon: Icons.key,
                  title: 'API Key',
                  subtitle: _aiConfigManager.apiKey.isEmpty
                      ? 'Not configured'
                      : '${_aiConfigManager.apiKey.substring(0, 8)}...',
                  onTap: () => _showAPIKeyDialog(),
                ),
                if (_aiConfigManager.currentProvider != AIProvider.ollama)
                  _SettingsTile(
                    icon: Icons.settings,
                    title: 'Model Settings',
                    subtitle: _aiConfigManager.model,
                    onTap: () => _showModelSettingsDialog(),
                  ),
                _SettingsTile(
                  icon: _aiConfigManager.isConfigured
                      ? Icons.check_circle
                      : Icons.error,
                  title: 'AI Status',
                  subtitle: _aiConfigManager.isConfigured
                      ? 'Ready'
                      : 'Not configured',
                  trailing: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _aiConfigManager.isConfigured
                          ? Colors.green
                          : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),

            // App Settings Section
            _SettingsSection(
              title: 'App Settings',
              children: [
                _SettingsTile(
                  icon: Icons.dark_mode,
                  title: 'Dark Mode',
                  subtitle: _darkModeEnabled ? 'Enabled' : 'Disabled',
                  trailing: Switch(
                    value: _darkModeEnabled,
                    onChanged: (value) {
                      setState(() => _darkModeEnabled = value);
                      _saveSettings();
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () {},
                ),
              ],
            ),

            // About Section
            _SettingsSection(
              title: 'About',
              children: [
                _SettingsTile(
                  icon: Icons.info,
                  title: 'About CityZen',
                  subtitle: 'Version 1.0.0',
                  onTap: () => _showAboutDialog(),
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.help,
                  title: 'Help & Support',
                  subtitle: 'Get help using CityZen',
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showUnitSelector(String type) {
    final isTemperature = type == 'temperature';
    final units = isTemperature ? _temperatureUnits : _distanceUnits;
    final currentUnit = isTemperature ? _temperatureUnit : _distanceUnit;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Select ${isTemperature ? 'Temperature' : 'Distance'} Unit',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...units.map(
              (unit) => ListTile(
                title: Text(unit),
                trailing: currentUnit == unit
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() {
                    if (isTemperature) {
                      _temperatureUnit = unit;
                    } else {
                      _distanceUnit = unit;
                    }
                  });
                  _saveSettings();
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.eco, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('CityZen'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Urban Health Companion',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'CityZen helps urban dwellers make informed decisions about outdoor activities by combining real-time environmental data with AI-powered recommendations.',
            ),
            SizedBox(height: 16),
            Text(
              'Version: 1.0.0\nBuild: 2024.12.26',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAIProviderSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Select AI Provider',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ...AIProvider.values.map(
              (provider) => ListTile(
                leading: Icon(_getProviderIcon(provider)),
                title: Text(provider.displayName),
                subtitle: Text(_aiConfigManager.getConfigHint(provider)),
                trailing: _aiConfigManager.currentProvider == provider
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () async {
                  await _aiConfigManager.saveConfig(provider: provider);
                  setState(() {});
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return Icons.auto_awesome;
      case AIProvider.openai:
        return Icons.psychology;
      case AIProvider.claude:
        return Icons.chat;
      case AIProvider.ollama:
        return Icons.computer;
    }
  }

  void _showAPIKeyDialog() {
    _apiKeyController.text = _aiConfigManager.apiKey;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${_aiConfigManager.currentProvider.displayName} API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'Enter your API key',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Text(
              _aiConfigManager.getConfigHint(_aiConfigManager.currentProvider),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final key = _apiKeyController.text.trim();
              if (_aiConfigManager.validateApiKey(
                key,
                _aiConfigManager.currentProvider,
              )) {
                await _aiConfigManager.saveConfig(apiKey: key);
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key saved successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid API Key format')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showModelSettingsDialog() {
    _customModelController.text = _aiConfigManager.model;
    _baseUrlController.text = _aiConfigManager.baseUrl;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Advanced AI Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customModelController,
              decoration: InputDecoration(
                labelText: 'Model Name',
                hintText: _aiConfigManager.currentProvider.defaultModel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.memory),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: 'Custom Base URL (Optional)',
                hintText: 'https://api.example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Leave empty to use default settings',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _aiConfigManager.saveConfig(
                customModel: _customModelController.text.trim(),
                baseUrl: _baseUrlController.text.trim(),
              );
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved successfully')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
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

// 网格点数据模型
class GridPoint {
  final LatLng location;
  final double? temperature;
  final double? precipitation;
  final double? pm25;
  final double? pm10;
  final double? ozone;
  final int? aqi;
  final int? weatherCode;

  GridPoint({
    required this.location,
    this.temperature,
    this.precipitation,
    this.pm25,
    this.pm10,
    this.ozone,
    this.aqi,
    this.weatherCode,
  });
}
