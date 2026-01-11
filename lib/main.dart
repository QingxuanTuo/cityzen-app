import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
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
import 'package:cityzen/responsive/responsive_layout.dart';
import 'package:cityzen/pages/environmental_data_master_detail.dart';
import 'package:cityzen/services/firebase_service.dart';
import 'package:cityzen/services/auth_service_demo.dart';
import 'package:cityzen/services/user_data_service.dart';
import 'package:cityzen/pages/auth/login_page.dart';
import 'package:cityzen/services/enhanced_air_quality_service.dart';
import 'package:cityzen/widgets/air_quality_heatmap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Firebase和认证服务
  try {
    await FirebaseService.instance.initialize();
    await AuthServiceDemo.instance.initialize();
    debugPrint('CITYZEN SERVICES INITIALIZED');
  } catch (e) {
    debugPrint('CITYZEN INITIALIZATION ERROR: $e');
  }
  
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
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MainShell(),
      },
    );
  }
}

// 认证包装器 - 根据认证状态显示不同页面
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthServiceDemo.instance,
      builder: (context, child) {
        final authService = AuthServiceDemo.instance;
        
        if (authService.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing...'),
                ],
              ),
            ),
          );
        }
        
        if (authService.isAuthenticated) {
          return const MainShell();
        } else {
          return const LoginPage();
        }
      },
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
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = AuthServiceDemo.instance.currentUser;
    if (user != null) {
      // 加载用户健康档案和设置
      await UserDataService.instance.getHealthProfile(user.uid);
      await UserDataService.instance.getFavoriteLocations(user.uid);
      await UserDataService.instance.getUserSettings(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onGoActivity: () => setState(() => _index = 2),
      ), // ✅ 跳到 Activity tab
      ResponsiveLayout(
        mobileLayout: const MapPage(),
        tabletLayout: const EnvironmentalDataMasterDetail(),
      ),
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
            icon: Icon(Icons.chat_outlined),
            label: 'AI Chat',
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
  List<double> _pm25Trend = [];
  final EnvironmentDataManager _envManager = EnvironmentDataManager();

  @override
  void initState() {
    super.initState();
    // 直接加载数据，不再显示欢迎对话框
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 使用指定的米兰坐标：45°28'51.3"N 9°13'30.4"E
      const lat = 45.4809167;
      const lon = 9.2251111;

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
      final pm25List = (aqHourly?['pm2_5'] as List?) ?? [];
      final trend = pm25List
          .where((e) => e is num)
          .map((e) => (e as num).toDouble())
          .toList();

      // 你图表是 12 个点：00,02,...22（每2小时一个点）
      // 所以从 hourly（24个点）里每隔2个取1个，最多取12个
      final sampled = <double>[];
      for (int i = 0; i < trend.length && sampled.length < 12; i += 2) {
        sampled.add(trend[i]);
      }

      setState(() {
        _pm25Trend = sampled;
      });

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

  // ✅ 右上角装饰 PNG：根据 Open-Meteo weathercode 映射
  String _weatherDecorAsset(int? code) {
    if (code == null) {
      return 'lib/assets/weather/cloudy.png';
    }

    // Clear / Sunny
    if (code == 0) {
      return 'lib/assets/weather/sunny.png';
    }

    // Mainly clear, partly cloudy, overcast
    if (code >= 1 && code <= 3) {
      return 'lib/assets/weather/cloudy.png';
    }

    // Fog
    if (code == 45 || code == 48) {
      return 'lib/assets/weather/fog.png';
    }

    // Drizzle
    if (code >= 51 && code <= 57) {
      return 'lib/assets/weather/drizzle.png';
    }

    // Rain / Showers
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return 'lib/assets/weather/showers.png';
    }

    // Snow
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return 'lib/assets/weather/snow.png';
    }

    // Thunderstorm
    if (code >= 95 && code <= 99) {
      return 'lib/assets/weather/flightning.png';
    }

    // Fallback
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
            Image.asset(
              'lib/assets/logo/cityzen_logo.png',
              height: 40, // ✅ 控制 logo 大小（重点）
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
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
                      'Milan, Italy',
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
            ? Center(child: Text('Loading failed:\n$_error', textAlign: TextAlign.center))
            : r == null
            ? const Center(child: Text('No data available'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ 顶部 Header：定位 + 问候 + 日期 + 时间（参考图布局）
                  const SizedBox(height: 0),
                  _HeaderTop(city: 'Milan, Italy'),
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
                        trendValues: _pm25Trend,
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  /// 🤖 AI Advice 卡片（可点击跳转到 AI Chat）
                  Card(
                    color: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: widget.onGoActivity, // ✅ 点这里切到 AI Chat tab
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'AI Advice >>',
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
  final List<double> trendValues;
  const _EAQICard({
    required this.pm25,
    required this.eaqiLabel,
    required this.eaqiColor,
    required this.advice,
    required this.trendValues,
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
            AirQualityTrend(values: trendValues, color: eaqiColor),
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

  final _milan = LatLng(45.4809167, 9.2251111); // 45°28'51.3"N 9°13'30.4"E
  // 当前“中心数据/标记”的位置，初始为米兰
  late LatLng _center = _milan;
  GridPoint? _centerData;
  List<ParkPoi> _nearbyParks = [];
  bool _loading = false;
  bool _parksLoading = false;
  String? _error;
  double _currentZoom = 15.0;
  LatLng _currentCenter = const LatLng(45.4809167, 9.2251111); // 45°28'51.3"N 9°13'30.4"E

  // 热力图相关
  final EnhancedAirQualityService _airQualityService = EnhancedAirQualityService();
  AirQualityGrid? _airQualityGrid;
  List<AirQualityStation> _stations = [];
  bool _showHeatmap = true;
  bool _showStations = true;
  String _selectedPollutant = 'PM2.5';

  @override
  void initState() {
    super.initState();
    _fetchCenterData();
    _loadAirQualityData(); // 加载热力图数据
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
      // 公园数据异步拉取，不阻塞主加载
      _loadParks(_center);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Load heatmap data with more stations
  Future<void> _loadAirQualityData() async {
    try {
      // Get nearby stations with larger radius to cover all Milan area
      final stations = await _airQualityService.getNearbyStations(
        _center, 
        50.0, // Increased to 50km radius to cover entire Milan metropolitan area
      );
      
      // Generate grid data for heatmap with larger bounds
      final bounds = LatLngBounds(
        LatLng(_center.latitude - 0.3, _center.longitude - 0.3), // Expanded bounds
        LatLng(_center.latitude + 0.3, _center.longitude + 0.3),
      );
      
      final grid = await _airQualityService.getAirQualityGrid(
        bounds, 
        1.5, // Reduced to 1.5km grid resolution for better coverage
      );
      
      if (mounted) {
        setState(() {
          _stations = stations;
          _airQualityGrid = grid;
        });
      }
      
      debugPrint('Loaded ${stations.length} air quality stations');
    } catch (e) {
      debugPrint('Error loading air quality data: $e');
    }
  }

  Future<void> _loadParks(LatLng center) async {
    setState(() => _parksLoading = true);
    try {
      final parks = await _fetchParksAround(center);
      if (!mounted) return;
      setState(() {
        _nearbyParks = parks;
        _parksLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _parksLoading = false);
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

  Future<List<ParkPoi>> _fetchParksAround(LatLng center) async {
    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://lz4.overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
    ];

    final query =
        '''
[out:json][timeout:12];
(
  node["leisure"="park"](around:2000,${center.latitude},${center.longitude});
  way["leisure"="park"](around:2000,${center.latitude},${center.longitude});
  relation["leisure"="park"](around:2000,${center.latitude},${center.longitude});
);
out center 30;
''';

    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint);
        final resp = await http
            .post(uri, body: {'data': query})
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode != 200) continue;

        final parks = _parseOverpassParks(resp.body);
        if (parks.isNotEmpty) return parks;
      } catch (_) {
        // 忽略单个端点失败，尝试下一个
        continue;
      }
    }

    return [];
  }

  List<ParkPoi> _parseOverpassParks(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final elements = (json['elements'] as List?) ?? [];

      final seen = <String>{};
      final parks = <ParkPoi>[];

      for (final e in elements) {
        final type = e['type'] as String?;
        double? lat;
        double? lon;
        if (type == 'node') {
          lat = (e['lat'] as num?)?.toDouble();
          lon = (e['lon'] as num?)?.toDouble();
        } else {
          final centerJson = e['center'] as Map<String, dynamic>?;
          lat = (centerJson?['lat'] as num?)?.toDouble();
          lon = (centerJson?['lon'] as num?)?.toDouble();
        }
        if (lat == null || lon == null) continue;

        final key = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
        if (!seen.add(key)) continue;

        final tags = e['tags'] as Map<String, dynamic>?;
        final name = tags?['name'] as String?;
        parks.add(
          ParkPoi(
            name: name?.isNotEmpty == true ? name! : 'Green area',
            location: LatLng(lat, lon),
          ),
        );
      }

      return parks;
    } catch (_) {
      return [];
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
      // 显示加载指示器
      if (mounted) {
        setState(() => _loading = true);
      }

      // 检查地理定位服务是否可用
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Location services are disabled. Please enable location services in your system settings.');
        return;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showLocationError('Location permission denied. Please click the location icon in your browser\'s address bar and allow location access.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permission permanently denied. Please go to browser settings and enable location for this site.');
        return;
      }

      // 尝试获取当前位置，使用更宽松的设置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // 降低精度要求
        timeLimit: const Duration(seconds: 10), // 减少超时时间
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Location request timed out. This may be due to browser security restrictions.');
        },
      );
      
      final userCenter = LatLng(position.latitude, position.longitude);
      
      if (!mounted) return;
      
      setState(() {
        _center = userCenter;
        _currentCenter = userCenter;
        _loading = false;
      });
      
      _mapController.move(userCenter, _currentZoom);
      await _fetchCenterData();
      await _loadAirQualityData(); // 重新加载空气质量数据
      
      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location updated: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      
      String errorMessage = 'Failed to get location: ';
      if (e is LocationServiceDisabledException) {
        errorMessage += 'Location services are disabled in your system';
      } else if (e is PermissionDeniedException) {
        errorMessage += 'Location permission denied by browser';
      } else if (e.toString().contains('timed out')) {
        errorMessage += 'Request timed out. Try enabling location in browser settings';
      } else if (e.toString().contains('Position update is unavailable')) {
        errorMessage += 'Browser location unavailable. Try refreshing the page or check browser settings';
      } else {
        errorMessage += e.toString();
      }
      
      _showLocationError(errorMessage);
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 4),
            const Text(
              'Tips: Check browser location settings or try refreshing the page',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Use Milan',
          textColor: Colors.white,
          onPressed: _recenterToDefault,
        ),
      ),
    );
  }

  void _showManualLocationDialog() {
    final latController = TextEditingController();
    final lonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g., 45.4809167',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lonController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g., 9.2251111',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            const Text(
              'Examples:\n• Milan: 45.4809, 9.2251\n• Rome: 41.9028, 12.4964\n• Florence: 43.7696, 11.2558',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lon = double.tryParse(lonController.text);
              
              if (lat != null && lon != null && 
                  lat >= -90 && lat <= 90 && 
                  lon >= -180 && lon <= 180) {
                Navigator.of(context).pop();
                _setManualLocation(lat, lon);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid coordinates'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Set Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _setManualLocation(double lat, double lon) async {
    final userCenter = LatLng(lat, lon);
    
    setState(() {
      _center = userCenter;
      _currentCenter = userCenter;
    });
    
    _mapController.move(userCenter, _currentZoom);
    await _fetchCenterData();
    await _loadAirQualityData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location set to: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
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
              initialZoom: 15,
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
                // 使用更美观的 CartoDB 地图样式
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.cityzen',
                additionalOptions: const {
                  'attribution': '© CartoDB © OpenStreetMap contributors',
                },
              ),
              
              // 热力图层 - 显示污染分布
              if (_showHeatmap && _airQualityGrid != null)
                AirQualityHeatmapLayer(
                  grid: _airQualityGrid!,
                  pollutant: _selectedPollutant,
                  opacity: 0.6,
                ),
              
              // 监测站标记层
              if (_showStations)
                AirQualityStationsLayer(
                  stations: _stations,
                  selectedPollutant: _selectedPollutant,
                  onStationTap: (station) {
                    showDialog(
                      context: context,
                      builder: (context) => StationDetailDialog(station: station),
                    );
                  },
                ),
              CircleLayer(
                circles: _nearbyParks
                    .map(
                      (park) => CircleMarker(
                        point: park.location,
                        color: Colors.green.withOpacity(0.16),
                        borderColor: Colors.green[700]!,
                        borderStrokeWidth: 1.5,
                        radius: 24,
                      ),
                    )
                    .toList(),
              ),
              // 仅显示中心点（米兰）
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _centerColor(),
                            _centerColor().withOpacity(0.8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  ..._nearbyParks.map(
                    (park) => Marker(
                      point: park.location,
                      width: 24,
                      height: 24,
                      child: Tooltip(
                        message: park.name,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green[700]!,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.park,
                            color: Colors.green[700],
                            size: 16,
                          ),
                        ),
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

          // No parks nearby notification
          if (_error == null &&
              !_loading &&
              !_parksLoading &&
              _nearbyParks.isEmpty)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.green[50],
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No parks/green areas found within 2 km',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ),
            ),

          // Unified Control Panel
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Pollutant selection
                    Row(
                      children: [
                        const Text('Pollutant: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Expanded(
                          child: Row(
                            children: [
                              _buildPollutantChip('PM2.5'),
                              const SizedBox(width: 4),
                              _buildPollutantChip('PM10'),
                              const SizedBox(width: 4),
                              _buildPollutantChip('O3'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Display options
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: _showHeatmap,
                                onChanged: (value) => setState(() => _showHeatmap = value ?? true),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              const Text('Heatmap', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Checkbox(
                                value: _showStations,
                                onChanged: (value) => setState(() => _showStations = value ?? true),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              const Text('Stations', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dynamic Heatmap Legend - positioned on the right side
          if (_showHeatmap)
            Positioned(
              top: 200, // 调整回更合适的位置
              right: 16,
              child: AirQualityLegend(
                pollutant: _selectedPollutant,
              ),
            ),

          // Manual location input button
          Positioned(
            bottom: 70,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'manualLocation',
              mini: true,
              backgroundColor: Colors.orange,
              onPressed: _showManualLocationDialog,
              child: const Icon(Icons.edit_location, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'recenter',
              mini: true,
              backgroundColor: _loading ? Colors.grey : Colors.white,
              onPressed: _loading ? null : _recenterToMyLocation,
              child: _loading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: AppColors.primary),
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

          // Bottom left: AQI Legend (only when heatmap is disabled)
          if (!_showHeatmap)
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

  // 构建污染物选择芯片
  Widget _buildPollutantChip(String pollutant) {
    final isSelected = _selectedPollutant == pollutant;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPollutant = pollutant;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            pollutant,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
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

class ParkPoi {
  final String name;
  final LatLng location;

  ParkPoi({required this.name, required this.location});
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
            "Hello! I'm your AI Environmental Health Assistant. I can provide daily life recommendations based on real-time environmental data to help you reduce environmental exposure risks. What would you like to know?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
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
      final aiResponse = await _aiService.getEnvironmentalAdvice(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildAIChat(),
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
                        hintText: 'Ask about environmental health...',
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
  String _temperatureUnit = 'Celsius';
  String _distanceUnit = 'Kilometers';
  double _airQualityThreshold = 25.0;
  double _windSpeedThreshold = 15.0;

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
    await prefs.setString('temperature_unit', _temperatureUnit);
    await prefs.setString('distance_unit', _distanceUnit);
    await prefs.setDouble('air_quality_threshold', _airQualityThreshold);
    await prefs.setDouble('wind_speed_threshold', _windSpeedThreshold);
  }

  void _showLocationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Location Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CityZen is currently configured for Milan, Italy.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Location: 45°28\'51.3"N 9°13\'30.4"E',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'All environmental data is sourced from monitoring stations in the Milan metropolitan area.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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
                  title: 'Location',
                  subtitle: 'Milan, Italy (Fixed)',
                  onTap: _showLocationInfo,
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
                if (_aiConfigManager.currentProvider != AIProvider.gemini)
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

            // Account Section
            _SettingsSection(
              title: 'Account',
              children: [
                _SettingsTile(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  subtitle: 'Switch to a different account',
                  onTap: () => _showLogoutDialog(),
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? You will need to sign in again to access your personalized data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthServiceDemo.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
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
