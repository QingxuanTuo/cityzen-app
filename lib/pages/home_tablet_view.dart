import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cityzen/theme/app_theme.dart';
import 'package:cityzen/environment_data.dart';
import 'package:cityzen/l10n/app_localizations.dart';

/// ✅ Tablet Home: SAME content as phone, only layout differs.
class TabletHomeView extends StatelessWidget {
  final bool loading;
  final String? error;
  final WeatherResult? result;
  final List<double> pm25Trend;

  final String locationLabel;
  final VoidCallback onRefresh;
  final VoidCallback? onGoAIChat;
  // ✅ 新增：来自 API 的时区偏移（秒）
  final int? utcOffsetSeconds;

  const TabletHomeView({
    super.key,
    required this.loading,
    required this.error,
    required this.result,
    required this.pm25Trend,
    required this.locationLabel,
    required this.onRefresh,
    this.onGoAIChat,
    this.utcOffsetSeconds, // ✅ 关键：必须在构造里初始化（可选参数）
  });

  ({IconData icon, String label}) _weatherInfo(int? code) {
    if (code == null) return (icon: Icons.help_outline, label: 'Unknown');
    if (code == 0) return (icon: Icons.wb_sunny, label: 'Clear');
    if (code <= 2) return (icon: Icons.wb_cloudy, label: 'Partly Cloudy');
    if (code <= 3) return (icon: Icons.cloud, label: 'Overcast');
    if (code == 45 || code == 48) return (icon: Icons.foggy, label: 'Fog');
    if (code >= 51 && code <= 67) return (icon: Icons.umbrella, label: 'Rain');
    if (code >= 71 && code <= 77) return (icon: Icons.ac_unit, label: 'Snow');
    return (icon: Icons.cloud, label: 'Unstable');
  }

  String _weatherDecorAsset(int? code) {
    if (code == null) return 'lib/assets/weather/cloudy.png';
    if (code == 0) return 'lib/assets/weather/sunny.png';
    if (code >= 1 && code <= 3) return 'lib/assets/weather/cloudy.png';
    if (code == 45 || code == 48) return 'lib/assets/weather/fog.png';
    if (code >= 51 && code <= 57) return 'lib/assets/weather/drizzle.png';
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return 'lib/assets/weather/showers.png';
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return 'lib/assets/weather/snow.png';
    }
    if (code >= 95 && code <= 99) return 'lib/assets/weather/flightning.png';
    return 'lib/assets/weather/cloudy.png';
  }

  ({String label, Color color}) _airQualityTag(double? pm25) {
    if (pm25 == null) return (label: 'No data', color: Colors.grey);
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

  @override
  Widget build(BuildContext context) {
    final r = result;
    final l10n = AppLocalizations.of(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(
          '${l10n?.loadingFailed ?? 'Loading failed'}:\n$error',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (r == null) {
      return Center(child: Text(l10n?.noDataAvailable ?? 'No data available'));
    }

    // ✅ 平板布局：Header 全宽 + 两列内容
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 18.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 36, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Header（之后我们再把 _TabletHeaderTop 改成横向+大时间）
              _TabletHeaderTop(
                location: locationLabel,
                utcOffsetSeconds: utcOffsetSeconds,
              ),

              const SizedBox(height: 16),

              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch, // ✅ 两列同高
                  children: [
                    Expanded(
                      flex: 52,
                      child: Column(
                        children: [
                          _WeatherCard(
                            r: r,
                            weatherLabel: _weatherInfo(r.weatherCode).label,
                            decorAsset: _weatherDecorAsset(r.weatherCode),
                            windTitle: l10n?.wind ?? 'Wind',
                            humidityTitle: l10n?.humidity ?? 'Humidity',
                            pm25Title: l10n?.pm25 ?? 'PM2.5',
                          ),
                          const SizedBox(height: 12),

                          const Spacer(), // ✅ 把 AI Advice 推到底部，底边对齐右侧 EAQI

                          Card(
                            color: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(26),
                              onTap: onGoAIChat,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 22),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat, color: Colors.white),
                                    SizedBox(width: 10),
                                    Text(
                                      'AI Advice >>',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
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
                        ],
                      ),
                    ),

                    const SizedBox(width: gap),

                    Expanded(
                      flex: 48,
                      child: Builder(
                        builder: (context) {
                          final tag = _airQualityTag(r.pm25);
                          return _EAQICardLikePhone(
                            pm25: r.pm25,
                            eaqiLabel: tag.label,
                            eaqiColor: tag.color,
                            advice: _eaqiAdvice(tag.label),
                            trendValues: pm25Trend,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }
}

/// ===============
/// 下面是“长得像手机端”的组件（都在同一个文件里，不需要动 main.dart）
/// ===============

class _LocationPill extends StatelessWidget {
  final String label;
  const _LocationPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
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
            size: 22,
            color: Colors.black.withOpacity(0.75),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _TabletHeaderTop extends StatelessWidget {
  final String location;
  final int? utcOffsetSeconds;

  const _TabletHeaderTop({
    required this.location,
    required this.utcOffsetSeconds,
  });

  String _two(int v) => v < 10 ? '0$v' : '$v';

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

  DateTime _localNow() {
    final utcNow = DateTime.now().toUtc();
    final offset = Duration(seconds: utcOffsetSeconds ?? 0);
    return utcNow.add(offset);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 30), (i) => i),
      builder: (context, _) {
        final now = _localNow(); // ✅ 用 API 偏移得到“城市当地时间”
        final h = now.hour;

        final l10n = AppLocalizations.of(context);
        final greet = h < 12
            ? (l10n?.goodMorning ?? 'Good Morning!')
            : h < 18
            ? (l10n?.goodAfternoon ?? 'Good Afternoon!')
            : (l10n?.goodEvening ?? 'Good Evening!');

        final dateLine =
            '${_weekday(now)}, ${now.day} ${_month(now)} ${now.year}';
        final timeLine = '${_two(now.hour)}:${_two(now.minute)}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：定位 + Good Afternoon
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _LocationPill(label: location),
                const SizedBox(width: 16),

                Text(
                  greet,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),

                const Spacer(),

                // 右侧大时间（保持原样）
                Text(
                  timeLine,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 第二行：日期（弱层级）
            Text(
              dateLine,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final WeatherResult r;
  final String weatherLabel;
  final String decorAsset;

  final String windTitle;
  final String humidityTitle;
  final String pm25Title;

  const _WeatherCard({
    required this.r,
    required this.weatherLabel,
    required this.decorAsset,
    required this.windTitle,
    required this.humidityTitle,
    required this.pm25Title,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.none,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFF1FC), Color(0xFFBFDFA3)],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ✅ 整体 padding 放大 → 卡片“更高更宽”
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 36, 30, 32),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.temperatureC == null
                                    ? '—'
                                    : '${r.temperatureC!.toStringAsFixed(1)} °C',
                                style: const TextStyle(
                                  fontSize: 52, // ✅ 温度略放大（平板更爽）
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.4,
                                ),
                              ),
                              const SizedBox(height: 20), // ✅ 行距增大
                              Text(
                                weatherLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16, // ✅ 描述文字放大
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),

                  const SizedBox(height: 28), // ✅ 内容区拉高

                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCardLikePhone(
                          title: windTitle,
                          value: r.windKmh == null
                              ? '—'
                              : r.windKmh!.toStringAsFixed(1),
                          unit: 'km/h',
                        ),
                      ),
                      const SizedBox(width: 14), // ✅ 横向更宽
                      Expanded(
                        child: _MiniStatCardLikePhone(
                          title: humidityTitle,
                          value: r.humidity == null
                              ? '—'
                              : r.humidity!.toStringAsFixed(0),
                          unit: '%',
                          background: const Color(0xFFD9F0A7),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MiniStatCardLikePhone(
                          title: pm25Title,
                          value: r.pm25 == null
                              ? '—'
                              : r.pm25!.toStringAsFixed(1),
                          unit: 'µg/m³',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ✅ 插画也跟着放大，不然会显小
            Positioned(
              right: -42,
              top: -58,
              child: IgnorePointer(
                ignoring: true,
                child: Image.asset(
                  decorAsset,
                  width: 260, // 👈 原来 230
                  height: 200, // 👈 原来 175
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCardLikePhone extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Color? background;

  const _MiniStatCardLikePhone({
    required this.title,
    required this.value,
    required this.unit,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
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
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.labelMedium?.copyWith(
              fontSize: 16, // ✅ 新增：原来大约是 12
              fontWeight: FontWeight.w700, // ✅ 稍微更稳
              letterSpacing: 0.2, // ✅ 平板更清晰
              color: Colors.black.withOpacity(0.65),
            ),
          ),

          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    letterSpacing: -0.4,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 14,
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
    );
  }
}

class _EAQICardLikePhone extends StatelessWidget {
  final double? pm25;
  final String eaqiLabel;
  final Color eaqiColor;
  final String advice;
  final List<double> trendValues;

  const _EAQICardLikePhone({
    required this.pm25,
    required this.eaqiLabel,
    required this.eaqiColor,
    required this.advice,
    required this.trendValues,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
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
                      fontSize: 15,
                      color: eaqiColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              advice,
              style: const TextStyle(
                fontSize: 17,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E2E2E),
              ),
            ),
            const SizedBox(height: 16),
            _AirQualityTrend(values: trendValues, color: eaqiColor),
            const SizedBox(height: 10),
            _legend(),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(String label, Color color) {
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
                style: const TextStyle(
                  fontSize: 14, // ✅ 原来 8
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          item('Good', const Color(0xFF4CAF50)),
          item('Fair', const Color(0xFF8BC34A)),
          item('Moderate', const Color(0xFFFFEB3B)),
          item('Poor', const Color(0xFFFF9800)),
          item('V.Poor', const Color(0xFFF44336)),
        ],
      ),
    );
  }
}

class _AirQualityTrend extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _AirQualityTrend({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox(height: 110);

    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return SizedBox(
      height: 250, // ✅ 平板更高一点，好看
      child: LineChart(
        LineChartData(
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
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9AA0A6),
                  );

                  final i = value.round();

                  // 12 个点（每 2 小时一个）
                  // index: 0  1  2  3  4  5  6  7  8  9 10 11
                  // label: 00    04    08    12    16    20
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

                  if (label == null) {
                    return const SizedBox.shrink();
                  }

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
              barWidth: 2.8,
              // ✅ 渐变（跟手机端一致）
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6CB8FF), // 蓝
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
