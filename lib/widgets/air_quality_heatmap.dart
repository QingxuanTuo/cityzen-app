import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/enhanced_air_quality_service.dart';
import 'dart:math' as math;

// 空气质量热力图组件
class AirQualityHeatmapLayer extends StatelessWidget {
  final AirQualityGrid grid;
  final String pollutant;
  final double opacity;
  
  const AirQualityHeatmapLayer({
    Key? key,
    required this.grid,
    required this.pollutant,
    this.opacity = 0.6,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return PolygonLayer(
      polygons: _generateHeatmapPolygons(),
    );
  }
  
  List<Polygon> _generateHeatmapPolygons() {
    final polygons = <Polygon>[];
    
    for (final point in grid.gridPoints) {
      final value = _getValueForPollutant(point, pollutant);
      if (value == null) continue;
      
      final color = _getColorForValue(value, pollutant);
      final bounds = _getGridCellBounds(point.location, grid.resolution);
      
      polygons.add(
        Polygon(
          points: [
            LatLng(bounds.south, bounds.west),
            LatLng(bounds.north, bounds.west),
            LatLng(bounds.north, bounds.east),
            LatLng(bounds.south, bounds.east),
          ],
          color: color.withOpacity(opacity),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    }
    
    return polygons;
  }
  
  double? _getValueForPollutant(GridPoint point, String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
        return point.pm25;
      case 'PM10':
        return point.pm10;
      case 'O3':
        return point.ozone;
      default:
        return null;
    }
  }
  
  Color _getColorForValue(double value, String pollutant) {
    final thresholds = _getThresholds(pollutant);
    final colors = _getColors(pollutant);
    
    for (int i = 0; i < thresholds.length - 1; i++) {
      if (value >= thresholds[i] && value < thresholds[i + 1]) {
        // 在两个阈值之间进行颜色插值
        final ratio = (value - thresholds[i]) / (thresholds[i + 1] - thresholds[i]);
        return Color.lerp(colors[i], colors[i + 1], ratio) ?? colors[i];
      }
    }
    
    // 超过最高阈值
    return colors.last;
  }
  
  List<double> _getThresholds(String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
        return [0, 5, 15, 25, 50, 75, 100, double.infinity];
      case 'PM10':
        return [0, 10, 20, 40, 80, 120, 200, double.infinity];
      case 'O3':
        return [0, 60, 120, 180, 240, 300, 400, double.infinity];
      default:
        return [0, 25, 50, 75, 100, 150, 200, double.infinity];
    }
  }
  
  List<Color> _getColors(String pollutant) {
    return [
      const Color(0xFF00E400), // 绿色 - 优
      const Color(0xFF7FFF00), // 黄绿 - 良
      const Color(0xFFFFFF00), // 黄色 - 轻度污染
      const Color(0xFFFF7F00), // 橙色 - 中度污染
      const Color(0xFFFF0000), // 红色 - 重度污染
      const Color(0xFF8F3F97), // 紫色 - 严重污染
      const Color(0xFF7E0023), // 褐红 - 极重污染
      const Color(0xFF7E0023), // 褐红 - 爆表
    ];
  }
  
  LatLngBounds _getGridCellBounds(LatLng center, double resolution) {
    final latOffset = resolution / 111.0 / 2; // 1度纬度约111km
    final lonOffset = resolution / (111.0 * math.cos(center.latitude * math.pi / 180)) / 2;
    
    return LatLngBounds(
      LatLng(center.latitude - latOffset, center.longitude - lonOffset),
      LatLng(center.latitude + latOffset, center.longitude + lonOffset),
    );
  }
}

// 空气质量监测站标记层
class AirQualityStationsLayer extends StatelessWidget {
  final List<AirQualityStation> stations;
  final String selectedPollutant;
  final Function(AirQualityStation)? onStationTap;
  
  const AirQualityStationsLayer({
    Key? key,
    required this.stations,
    required this.selectedPollutant,
    this.onStationTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: stations.map((station) => _buildStationMarker(station)).toList(),
    );
  }
  
  Marker _buildStationMarker(AirQualityStation station) {
    final value = _getStationValue(station, selectedPollutant);
    final color = value != null 
        ? _getColorForValue(value, selectedPollutant)
        : Colors.grey;
    
    return Marker(
      point: station.location,
      width: 24,
      height: 24,
      child: GestureDetector(
        onTap: () => onStationTap?.call(station),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.sensors,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ),
    );
  }
  
  double? _getStationValue(AirQualityStation station, String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
        return station.pm25;
      case 'PM10':
        return station.pm10;
      case 'O3':
        return station.ozone;
      default:
        return null;
    }
  }
  
  Color _getColorForValue(double value, String pollutant) {
    // 复用热力图的颜色逻辑
    final thresholds = _getThresholds(pollutant);
    final colors = _getColors(pollutant);
    
    for (int i = 0; i < thresholds.length - 1; i++) {
      if (value >= thresholds[i] && value < thresholds[i + 1]) {
        return colors[i];
      }
    }
    
    return colors.last;
  }
  
  List<double> _getThresholds(String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
        return [0, 5, 15, 25, 50, 75, 100];
      case 'PM10':
        return [0, 10, 20, 40, 80, 120, 200];
      case 'O3':
        return [0, 60, 120, 180, 240, 300, 400];
      default:
        return [0, 25, 50, 75, 100, 150, 200];
    }
  }
  
  List<Color> _getColors(String pollutant) {
    return [
      const Color(0xFF00E400), // 绿色 - 优
      const Color(0xFF7FFF00), // 黄绿 - 良
      const Color(0xFFFFFF00), // 黄色 - 轻度污染
      const Color(0xFFFF7F00), // 橙色 - 中度污染
      const Color(0xFFFF0000), // 红色 - 重度污染
      const Color(0xFF8F3F97), // 紫色 - 严重污染
      const Color(0xFF7E0023), // 褐红 - 极重污染
    ];
  }
}

// 空气质量图例
class AirQualityLegend extends StatelessWidget {
  final String pollutant;
  
  const AirQualityLegend({
    Key? key,
    required this.pollutant,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final thresholds = _getThresholds(pollutant);
    final colors = _getColors(pollutant);
    final labels = _getLabels(pollutant);
    final unit = _getUnit(pollutant);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$pollutant ($unit)',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            math.min(labels.length, colors.length),
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colors[index],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[index],
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<double> _getThresholds(String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
        return [0, 5, 15, 25, 50, 75, 100];
      case 'PM10':
        return [0, 10, 20, 40, 80, 120, 200];
      case 'O3':
        return [0, 60, 120, 180, 240, 300, 400];
      default:
        return [0, 25, 50, 75, 100, 150, 200];
    }
  }
  
  List<Color> _getColors(String pollutant) {
    return [
      const Color(0xFF00E400), // 绿色 - 优
      const Color(0xFF7FFF00), // 黄绿 - 良
      const Color(0xFFFFFF00), // 黄色 - 轻度污染
      const Color(0xFFFF7F00), // 橙色 - 中度污染
      const Color(0xFFFF0000), // 红色 - 重度污染
      const Color(0xFF8F3F97), // 紫色 - 严重污染
      const Color(0xFF7E0023), // 褐红 - 极重污染
    ];
  }
  
  List<String> _getLabels(String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
        return ['优 (0-5)', '良 (5-15)', '轻度 (15-25)', '中度 (25-50)', '重度 (50-75)', '严重 (75-100)', '爆表 (100+)'];
      case 'PM10':
        return ['优 (0-10)', '良 (10-20)', '轻度 (20-40)', '中度 (40-80)', '重度 (80-120)', '严重 (120-200)', '爆表 (200+)'];
      case 'O3':
        return ['优 (0-60)', '良 (60-120)', '轻度 (120-180)', '中度 (180-240)', '重度 (240-300)', '严重 (300-400)', '爆表 (400+)'];
      default:
        return ['优', '良', '轻度污染', '中度污染', '重度污染', '严重污染', '爆表'];
    }
  }
  
  String _getUnit(String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
      case 'PM10':
        return 'µg/m³';
      case 'O3':
        return 'µg/m³';
      default:
        return '';
    }
  }
}

// 监测站详情弹窗
class StationDetailDialog extends StatelessWidget {
  final AirQualityStation station;
  
  const StationDetailDialog({
    Key? key,
    required this.station,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(station.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('数据源: ${station.source}'),
          const SizedBox(height: 8),
          if (station.pm25 != null)
            _buildDataRow('PM2.5', station.pm25!, 'µg/m³'),
          if (station.pm10 != null)
            _buildDataRow('PM10', station.pm10!, 'µg/m³'),
          if (station.ozone != null)
            _buildDataRow('臭氧', station.ozone!, 'µg/m³'),
          if (station.aqi != null)
            _buildDataRow('AQI', station.aqi!, ''),
          const SizedBox(height: 8),
          Text(
            '更新时间: ${_formatDateTime(station.lastUpdated)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
  
  Widget _buildDataRow(String label, double value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('${value.toStringAsFixed(1)} $unit'),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}