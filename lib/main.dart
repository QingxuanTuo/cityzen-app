import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:cityzen/theme/app_theme.dart';
import 'package:cityzen/ai_service.dart';
import 'package:cityzen/environment_data.dart';
import 'package:cityzen/ai_config.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cityzen/responsive/responsive_layout.dart';
import 'package:cityzen/pages/environmental_data_master_detail.dart';
import 'package:cityzen/services/firebase_service.dart';
import 'package:cityzen/services/auth_service_demo.dart';
import 'package:cityzen/services/user_data_service.dart';
import 'package:cityzen/pages/auth/login_page.dart';
import 'package:cityzen/pages/simplified_map_page.dart';
import 'package:cityzen/pages/tablet_home_page.dart';
import 'package:cityzen/services/background_data_service.dart';
import 'package:cityzen/services/locale_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cityzen/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化语言服务
  await LocaleService().init();

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
    return ListenableBuilder(
      listenable: LocaleService(),
      builder: (context, child) {
        final localeService = LocaleService();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'CityZen',
          theme: AppTheme.light(),
          locale: localeService.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginPage(),
            '/home': (context) => const MainShell(),
          },
        );
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
      ResponsiveLayout(
        mobileLayout: HomePage(onGoActivity: () => setState(() => _index = 2)),
        tabletLayout: HomePage(onGoActivity: () => setState(() => _index = 2)),
        desktopLayout: HomePage(onGoActivity: () => setState(() => _index = 2)),
      ),
      ResponsiveLayout(
        mobileLayout: const SimplifiedMapPage(),
        tabletLayout: const SimplifiedMapPage(),
        desktopLayout: const SimplifiedMapPage(),
      ),
      ResponsiveLayout(
        mobileLayout: const ActivityPage(),
        tabletLayout: const ActivityPage(),
        desktopLayout: const ActivityPage(),
      ),
      ResponsiveLayout(
        mobileLayout: const SettingsPage(),
        tabletLayout: const SettingsPage(),
        desktopLayout: const SettingsPage(),
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: AppLocalizations.of(context)?.home ?? 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            label: AppLocalizations.of(context)?.map ?? 'Map',
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_outlined),
            label: AppLocalizations.of(context)?.aiChat ?? 'AI Chat',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: AppLocalizations.of(context)?.settings ?? 'Settings',
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
    debugPrint('[_fetchWeather] CALLED at ${DateTime.now()}'); // ✅ 加在这里

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

      final times = (aqHourly?['time'] as List?) ?? [];
      final pm25Raw = (aqHourly?['pm2_5'] as List?) ?? [];
      final pm10Raw = (aqHourly?['pm10'] as List?) ?? [];

      // 1) 把 time + value 对齐成列表（允许中间有 null）
      DateTime? parseTime(dynamic t) {
        if (t is String) {
          // Open-Meteo 返回类似 "2026-01-11T16:00"
          return DateTime.tryParse(t);
        }
        return null;
      }

      // 找到“最接近现在”的小时索引
      final now = DateTime.now();
      int nearestHourIndex = 0;
      Duration best = const Duration(days: 9999);

      for (int i = 0; i < times.length; i++) {
        final dt = parseTime(times[i]);
        if (dt == null) continue;
        final d = (dt.difference(now)).abs();
        if (d < best) {
          best = d;
          nearestHourIndex = i;
        }
      }

      // 2) 当前值：用 nearestHourIndex，而不是 last
      double? pickNumAt(List<dynamic> list, int idx) {
        if (idx < 0 || idx >= list.length) return null;
        final v = list[idx];
        return v is num ? v.toDouble() : null;
      }

      final pm25 = pickNumAt(pm25Raw, nearestHourIndex);
      final pm10 = pickNumAt(pm10Raw, nearestHourIndex);

      // 3) 趋势：从“当前小时”开始，每隔2小时取1个，取12个点
      final sampled = <double>[];
      for (
        int i = nearestHourIndex;
        i < pm25Raw.length && sampled.length < 12;
        i += 2
      ) {
        final v = pm25Raw[i];
        if (v is num) sampled.add(v.toDouble());
      }

      // 如果后面点不够（比如接口只给到未来较短范围），就从前面补齐
      if (sampled.length < 12) {
        for (int i = 0; i < pm25Raw.length && sampled.length < 12; i += 2) {
          final v = pm25Raw[i];
          if (v is num) sampled.add(v.toDouble());
        }
      }

      setState(() {
        _pm25Trend = sampled;
      });

      // 观察：看看 index 和时间是否对
      debugPrint(
        'AQI now=$now nearestIndex=$nearestHourIndex time=${times.isNotEmpty ? times[nearestHourIndex] : 'N/A'} pm25=$pm25 pm10=$pm10',
      );

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

        // ✅ AppBar 下方加"定位 pill"，像你参考图那样
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
                      AppLocalizations.of(context)?.milanItaly ??
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: _loading
            ? const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? Center(
                child: Text(
                  '${AppLocalizations.of(context)?.loadingFailed ?? 'Loading failed'}:\n$_error',
                  textAlign: TextAlign.center,
                ),
              )
            : r == null
            ? Center(
                child: Text(
                  AppLocalizations.of(context)?.noDataAvailable ??
                      'No data available',
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ 顶部 Header：定位 + 问候 + 日期 + 时间（参考图布局）
                  const SizedBox(height: 0),
                  _HeaderTop(
                    city:
                        AppLocalizations.of(context)?.milanItaly ??
                        'Milan, Italy',
                  ),
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
                                        title:
                                            AppLocalizations.of(
                                              context,
                                            )?.wind ??
                                            'Wind',
                                        value: r.windKmh == null
                                            ? '—'
                                            : r.windKmh!.toStringAsFixed(1),
                                        unit: 'km/h',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MiniStatCard(
                                        title:
                                            AppLocalizations.of(
                                              context,
                                            )?.humidity ??
                                            'Humidity',
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
                                            title:
                                                AppLocalizations.of(
                                                  context,
                                                )?.pm25 ??
                                                'PM2.5',
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
                  const SizedBox(height: 8),
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

                  const SizedBox(height: 4),

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
                            const Icon(Icons.chat, color: Colors.white),
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

                  const SizedBox(height: 90),
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

  String _greeting(BuildContext context, DateTime now) {
    final l10n = AppLocalizations.of(context);
    final h = now.hour;
    if (h < 12) return l10n?.goodMorning ?? 'Good Morning!';
    if (h < 18) return l10n?.goodAfternoon ?? 'Good Afternoon!';
    return l10n?.goodEvening ?? 'Good Evening!';
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
    final greeting = _greeting(context, now);
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
            const SizedBox(height: 16),

            // 图表标题和图例
            const SizedBox(height: 8),

            // 小趋势图（示例数据：12个点=一天趋势）
            AirQualityTrend(values: trendValues, color: eaqiColor),

            const SizedBox(height: 8),

            // 简化的空气质量等级说明
            _buildSimpleAQILegend(),
          ],
        ),
      ),
    );
  }

  // 迷你图例
  Widget _buildMiniLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 2,
            decoration: BoxDecoration(
              color: eaqiColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'PM2.5',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // 简化的空气质量等级说明
  Widget _buildSimpleAQILegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildMiniAQIItem('Good', const Color(0xFF4CAF50)),
          _buildMiniAQIItem('Fair', const Color(0xFF8BC34A)),
          _buildMiniAQIItem('Moderate', const Color(0xFFFFEB3B)),
          _buildMiniAQIItem('Poor', const Color(0xFFFF9800)),
          _buildMiniAQIItem('V.Poor', const Color(0xFFF44336)),
        ],
      ),
    );
  }

  // 迷你空气质量项
  Widget _buildMiniAQIItem(String label, Color color) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 8),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
  final AIConfigManager _aiConfigManager = AIConfigManager();

  // 当前环境数据（从全局管理器获取）
  EnvironmentData? get _currentEnvironmentData => _envManager.currentData;

  @override
  void initState() {
    super.initState();
    _aiService = GeminiAIService();
    // 延迟添加欢迎消息，确保context可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _addWelcomeMessage();
      }
    });

    // 监听环境数据变化
    _envManager.addListener(_onEnvironmentDataChanged);

    // 监听AI配置变化，确保配置保存后页面会重建
    _aiConfigManager.addListener(_onAIConfigChanged);

    // 刷新AI配置
    _refreshAIService();
  }

  Future<void> _refreshAIService() async {
    await _aiService.refreshConfig();
  }

  @override
  void dispose() {
    _envManager.removeListener(_onEnvironmentDataChanged);
    _aiConfigManager.removeListener(_onAIConfigChanged);
    super.dispose();
  }

  void _onEnvironmentDataChanged() {
    if (mounted) {
      setState(() {
        // 环境数据更新时刷新UI
      });
    }
  }

  void _onAIConfigChanged() {
    if (mounted) {
      setState(() {
        // AI配置更新时刷新UI，确保_buildAIChat()使用最新的配置状态
      });
    }
  }

  void _addWelcomeMessage() {
    final l10n = AppLocalizations.of(context);
    _chatMessages.add(
      ChatMessage(
        text:
            l10n?.aiWelcomeMessage ??
            "Hello! I'm your AI Environmental Health Assistant. I can provide daily life recommendations based on real-time environmental data to help you reduce environmental exposure risks. What would you like to know?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _sendChatMessage(String message) async {
    if (message.trim().isEmpty) return;

    // 检查API配置，如果没有配置，提示用户去Settings配置
    if (!_aiConfigManager.isConfigured) {
      setState(() {
        _chatMessages.add(
          ChatMessage(text: message, isUser: true, timestamp: DateTime.now()),
        );
        _chatMessages.add(
          ChatMessage(
            text:
                "Please configure your AI API key in Settings to use the AI assistant. Go to Settings > AI Configuration to enter your Gemini API key.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _chatController.clear();
      return;
    }

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
        title: Text(AppLocalizations.of(context)?.aiChat ?? 'AI Chat'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildAIChat(),
    );
  }

  Widget _buildAIChat() {
    // 直接显示聊天界面和快速问题卡片，不再检查配置状态
    // API配置在Settings页面完成，发送消息时再检查配置
    final isTablet = ScreenSize.isTablet(context);

    // 使用LayoutBuilder获取可用高度，确保不会溢出
    return LayoutBuilder(
      builder: (context, constraints) {
        // 在非手机设备上，快速问题卡片使用固定的小高度
        final screenWidth = MediaQuery.of(context).size.width;
        final useCompactLayout = screenWidth >= 600;

        return Column(
          children: [
            // Quick questions cards
            _buildQuickQuestionCards(),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      reverse: false,
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
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText:
                                  AppLocalizations.of(
                                    context,
                                  )?.askAboutEnvironmentalHealth ??
                                  'Ask about environmental health...',
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
                            maxLines: null,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickQuestionCards() {
    final l10n = AppLocalizations.of(context);

    // 强制判断：只要不是手机（宽度>=600），就用紧凑布局
    final screenWidth = MediaQuery.of(context).size.width;
    final useCompactLayout = screenWidth >= 600;

    final quickQuestions = [
      {
        'icon': Icons.air,
        'title': l10n?.airQuality ?? 'Air Quality',
        'question':
            l10n?.whatIsCurrentAirQuality ??
            'What is the current air quality like?',
        'color': Colors.blue,
      },
      {
        'icon': Icons.directions_walk,
        'title': l10n?.outdoorActivity ?? 'Outdoor Activity',
        'question':
            l10n?.isItSafeToExerciseOutdoors ??
            'Is it safe to exercise outdoors today?',
        'color': Colors.green,
      },
      {
        'icon': Icons.health_and_safety,
        'title': l10n?.healthTips ?? 'Health Tips',
        'question':
            l10n?.giveMeHealthRecommendations ??
            'Give me health recommendations for today',
        'color': Colors.orange,
      },
      {
        'icon': Icons.warning,
        'title': l10n?.precautions ?? 'Precautions',
        'question':
            l10n?.whatPrecautionsShouldITake ??
            'What precautions should I take today?',
        'color': Colors.red,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 使用直接判断，避免ResponsiveContainer干扰
        // 在平板/桌面上：显示一行4个卡片，使用超大的aspectRatio让卡片非常矮
        // 在手机上：显示两行2个卡片
        final crossAxisCount = useCompactLayout ? 4 : 2;
        final aspectRatio = useCompactLayout ? 3.5 : 1.4;
        final spacing = useCompactLayout ? 6.0 : 8.0;

        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            useCompactLayout ? 4 : 12,
            16,
            useCompactLayout ? 4 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: useCompactLayout ? 4 : 10),
                child: Text(
                  l10n?.quickQuestions ?? 'Quick Questions',
                  style: TextStyle(
                    fontSize: useCompactLayout ? 10 : 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: quickQuestions.length,
                itemBuilder: (context, index) {
                  final item = quickQuestions[index];
                  return _buildQuickQuestionCard(
                    icon: item['icon'] as IconData,
                    title: item['title'] as String,
                    question: item['question'] as String,
                    color: item['color'] as Color,
                    isTablet: useCompactLayout,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickQuestionCard({
    required IconData icon,
    required String title,
    required String question,
    required Color color,
    bool isTablet = false,
  }) {
    return InkWell(
      onTap: () => _sendChatMessage(question),
      borderRadius: BorderRadius.circular(isTablet ? 8 : 10),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(isTablet ? 8 : 10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 6 : 10,
            vertical: isTablet ? 4 : 10,
          ),
          child: isTablet
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 14),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            question,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                              height: 1.15,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
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
              AppLocalizations.of(context)?.aiIsThinking ?? 'AI is thinking...',
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
  String _temperatureUnit = 'Celsius';
  final AIConfigManager _aiConfigManager = AIConfigManager();
  final BackgroundDataService _backgroundService =
      BackgroundDataService.instance;
  bool _backgroundDataEnabled = false;

  // User profile state
  String _userName = 'CityZen User';
  String _userDescription = 'Environmental Health Enthusiast';

  @override
  void initState() {
    super.initState();
    _aiConfigManager.loadConfig();
    // Listen to locale changes
    LocaleService().addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleService().removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    setState(() {
      // Update default values based on locale
      final l10n = AppLocalizations.of(context);
      if (_userName == 'CityZen User' || _userName == 'Utente CityZen') {
        _userName = l10n?.cityZenUser ?? 'CityZen User';
      }
      if (_userDescription == 'Environmental Health Enthusiast' ||
          _userDescription == 'Appassionato di Salute Ambientale') {
        _userDescription =
            l10n?.environmentalHealthEnthusiast ??
            'Environmental Health Enthusiast';
      }
    });
  }

  void _showEditProfileDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: _userName);
    final descriptionController = TextEditingController(text: _userDescription);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.editProfile ?? 'Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n?.name ?? 'Name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: l10n?.description ?? 'Description',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _userName = nameController.text.trim().isEmpty
                    ? (l10n?.cityZenUser ?? 'CityZen User')
                    : nameController.text.trim();
                _userDescription = descriptionController.text.trim().isEmpty
                    ? (l10n?.environmentalHealthEnthusiast ??
                          'Environmental Health Enthusiast')
                    : descriptionController.text.trim();
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n?.profileUpdatedSuccessfully ??
                        'Profile updated successfully',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(l10n?.save ?? 'Save'),
          ),
        ],
      ),
    );
  }

  void _showAIConfigDialog(BuildContext context) {
    final TextEditingController apiKeyController = TextEditingController();
    apiKeyController.text = _aiConfigManager.apiKey;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure Gemini AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google Gemini API key to enable AI chat features.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIza...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Text(
              'Get your API key from: https://aistudio.google.com/api-keys',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final apiKey = apiKeyController.text.trim();
              if (apiKey.isNotEmpty) {
                await _aiConfigManager.saveConfig(
                  provider: AIProvider.gemini,
                  apiKey: apiKey,
                );
                setState(() {}); // 刷新UI
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AI configuration saved successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showThreadingDemo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Multi-Threading Demo'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CityZen demonstrates multi-threading through:'),
            SizedBox(height: 8),
            Text('• Background Isolates for data processing'),
            Text('• Compute functions for heavy calculations'),
            Text('• Concurrent API calls with Future.wait'),
            Text('• Stream-based async data processing'),
            SizedBox(height: 12),
            Text(
              'Enable "Background Data Sync" to see Isolates in action!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.settings ?? 'Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ResponsiveContainer(
        maxWidth: ScreenSize.isTablet(context) ? 900 : null,
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              _SettingsSection(
                title: AppLocalizations.of(context)?.profile ?? 'Profile',
                children: [
                  _SettingsCard(
                    child: InkWell(
                      onTap: () => _showEditProfileDialog(context),
                      borderRadius: BorderRadius.circular(16),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userDescription,
                                  style: const TextStyle(
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
                  ),
                ],
              ),

              // Location & Data Section
              _SettingsSection(
                title:
                    AppLocalizations.of(context)?.locationAndData ??
                    'Location & Data',
                children: [
                  _SettingsTile(
                    icon: Icons.location_city,
                    title: AppLocalizations.of(context)?.location ?? 'Location',
                    subtitle:
                        AppLocalizations.of(context)?.milanItaly ??
                        'Milan, Italy',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.my_location,
                    title:
                        AppLocalizations.of(context)?.locationServices ??
                        'Location Services',
                    subtitle: _locationEnabled
                        ? (AppLocalizations.of(context)?.enabled ?? 'Enabled')
                        : (AppLocalizations.of(context)?.disabled ??
                              'Disabled'),
                    trailing: Switch(
                      value: _locationEnabled,
                      onChanged: (value) {
                        setState(() => _locationEnabled = value);
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                ],
              ),

              // Notifications Section
              _SettingsSection(
                title:
                    AppLocalizations.of(context)?.notifications ??
                    'Notifications',
                children: [
                  _SettingsTile(
                    icon: Icons.notifications,
                    title:
                        AppLocalizations.of(context)?.pushNotifications ??
                        'Push Notifications',
                    subtitle: _notificationsEnabled
                        ? (AppLocalizations.of(context)?.enabled ?? 'Enabled')
                        : (AppLocalizations.of(context)?.disabled ??
                              'Disabled'),
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                ],
              ),

              // Language Section
              _SettingsSection(
                title: AppLocalizations.of(context)?.language ?? 'Language',
                children: [
                  _SettingsTile(
                    icon: Icons.language,
                    title: AppLocalizations.of(context)?.language ?? 'Language',
                    subtitle: LocaleService().locale.languageCode == 'it'
                        ? (AppLocalizations.of(context)?.italian ?? 'Italian')
                        : (AppLocalizations.of(context)?.english ?? 'English'),
                    onTap: () {
                      final currentLocale = LocaleService().locale;
                      final newLocale = currentLocale.languageCode == 'it'
                          ? const Locale('en')
                          : const Locale('it');
                      LocaleService().setLocale(newLocale);
                    },
                  ),
                ],
              ),

              // Performance & Threading Section
              _SettingsSection(
                title: 'Performance & Threading',
                children: [
                  _SettingsTile(
                    icon: Icons.sync,
                    title: 'Background Data Sync',
                    subtitle: _backgroundDataEnabled
                        ? 'Active (Multi-threading)'
                        : 'Disabled',
                    trailing: Switch(
                      value: _backgroundDataEnabled,
                      onChanged: (value) async {
                        if (value) {
                          await _backgroundService.startBackgroundFetching();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Background data sync enabled (using Isolates)',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          await _backgroundService.stopBackgroundFetching();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Background data sync disabled'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                        setState(() => _backgroundDataEnabled = value);
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.memory,
                    title: 'Threading Demo',
                    subtitle: 'Test multi-threading capabilities',
                    onTap: () => _showThreadingDemo(),
                  ),
                ],
              ),

              // AI Configuration Section
              _SettingsSection(
                title: 'AI Assistant',
                children: [
                  _SettingsTile(
                    icon: Icons.smart_toy,
                    title: 'AI Configuration',
                    subtitle: AIConfigManager().isConfigured
                        ? 'Gemini AI configured'
                        : 'Configure Gemini API key',
                    onTap: () => _showAIConfigDialog(context),
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
                    subtitle: 'Version 1.0.0 - Environmental Health Assistant',
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
                    onTap: () async {
                      await AuthServiceDemo.instance.signOut();
                      if (mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
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
