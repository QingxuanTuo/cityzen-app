import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../services/milan_health_service.dart';
import '../models/health_zone.dart';
import '../models/safe_route.dart';
import '../theme/app_theme.dart';

class SimplifiedMapPage extends StatefulWidget {
  const SimplifiedMapPage({super.key});

  @override
  State<SimplifiedMapPage> createState() => _SimplifiedMapPageState();
}

class _SimplifiedMapPageState extends State<SimplifiedMapPage> {
  final _mapController = MapController();
  final _milanHealthService = MilanHealthService.instance;
  
  final _milan = LatLng(45.4809167, 9.2251111); // 45°28'51.3"N 9°13'30.4"E
  late LatLng _center = _milan;
  
  bool _loading = false;
  String? _error;
  double _currentZoom = 13.0;
  LatLng _currentCenter = const LatLng(45.4809167, 9.2251111);
  
  // 简化后的地图模式
  String _selectedMode = 'health_zones'; // 'health_zones' 或 'safe_routes'
  List<HealthZone> _healthZones = [];
  List<SafeRoute> _safeRoutes = [];
  List<ActivityRecommendation> _recommendations = [];
  
  HealthZone? _selectedZone;
  SafeRoute? _selectedRoute;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 加载健康区域和安全路线数据
      _healthZones = _milanHealthService.getHealthZones();
      _safeRoutes = _milanHealthService.getSafeRoutes();
      
      // 获取当前时间的活动建议
      _recommendations = _milanHealthService.getCurrentRecommendations();
      
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // 检查是否点击了健康区域
    if (_selectedMode == 'health_zones') {
      for (final zone in _healthZones) {
        final distance = _calculateDistance(point, zone.center);
        if (distance <= zone.radius / 1000) { // 转换为公里
          _showZoneDetails(zone);
          return;
        }
      }
    }
    
    // 检查是否点击了安全路线
    if (_selectedMode == 'safe_routes') {
      for (final route in _safeRoutes) {
        // 简单检查是否点击了路线附近
        for (final routePoint in route.points) {
          final distance = _calculateDistance(point, routePoint);
          if (distance <= 0.1) { // 100米内
            _showRouteDetails(route);
            return;
          }
        }
      }
    }
  }

  void _showZoneDetails(HealthZone zone) {
    setState(() {
      _selectedZone = zone;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildZoneBottomSheet(zone),
    );
  }

  void _showRouteDetails(SafeRoute route) {
    setState(() {
      _selectedRoute = route;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildRouteBottomSheet(route),
    );
  }

  Widget _buildZoneBottomSheet(HealthZone zone) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：拖拽指示器 + 关闭按钮
              Row(
                children: [
                  // 拖拽指示器
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // 关闭按钮
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedZone = null;
                      });
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8), // 减少间距
              
              // 区域标题和评分
              Row(
                children: [
                  Icon(zone.typeIcon, size: 24, color: zone.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          zone.healthLevel,
                          style: TextStyle(
                            color: zone.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: zone.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: zone.color),
                    ),
                    child: Text(
                      '${zone.healthScore}/100',
                      style: TextStyle(
                        color: zone.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 描述
              Text(
                zone.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              
              const SizedBox(height: 16),
              
              // 最佳时间
              if (zone.bestTimes.isNotEmpty) ...[
                Text(
                  'Best Times',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: zone.bestTimes.map((time) => Chip(
                    label: Text(time),
                    backgroundColor: zone.isOptimalTime(DateTime.now()) 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.grey.withOpacity(0.2),
                  )).toList(),
                ),
                const SizedBox(height: 16),
              ],
              
              // 建议
              if (zone.recommendations.isNotEmpty) ...[
                Text(
                  'Recommendations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: zone.recommendations.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, 
                                 color: zone.color, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(zone.recommendations[index]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteBottomSheet(SafeRoute route) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：拖拽指示器 + 关闭按钮
              Row(
                children: [
                  // 拖拽指示器
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // 关闭按钮
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedRoute = null;
                      });
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8), // 减少间距
              
              // 路线标题和评分
              Row(
                children: [
                  Icon(route.typeIcon, size: 24, color: route.routeColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${route.typeName} • ${route.estimatedTime}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: route.routeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: route.routeColor),
                    ),
                    child: Text(
                      '${route.healthScore}/100',
                      style: TextStyle(
                        color: route.routeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 描述和空气质量
              Text(route.description),
              const SizedBox(height: 8),
              Text(
                'Air Quality: ${route.airQualityLevel}',
                style: TextStyle(
                  color: route.routeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 当前时间建议
              if (route.getCurrentTimeRecommendation() != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          route.getCurrentTimeRecommendation()!,
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 亮点和警告
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (route.highlights.isNotEmpty) ...[
                        Text(
                          'Highlights',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...route.highlights.map((highlight) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(highlight)),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],
                      
                      if (route.warnings.isNotEmpty) ...[
                        Text(
                          'Warnings',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...route.warnings.map((warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning, color: Colors.orange, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(warning)),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton('Health Zones', 'health_zones', Icons.location_city),
          _buildModeButton('Safe Routes', 'safe_routes', Icons.route),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, String mode, IconData icon) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _selectedZone = null;
          _selectedRoute = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    if (_recommendations.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Recommendations',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recommendations.take(2).map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(rec.icon, color: rec.color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      Text(
                        rec.description,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // 计算两点间距离（公里）
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0;
    
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLonRad = (point2.longitude - point1.longitude) * math.pi / 180;
    
    final a = math.pow(math.sin(deltaLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.pow(math.sin(deltaLonRad / 2), 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  // 构建图例面板
  Widget _buildLegendPanel() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200), // 缩小宽度
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // 缩小圆角
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6, // 缩小阴影
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图例标题 - 缩小
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8), // 缩小内边距
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.legend_toggle, size: 14, color: AppColors.primary), // 缩小图标
                const SizedBox(width: 6),
                Text(
                  'Legend',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // 缩小字体
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          
          // 图例内容 - 缩小
          Padding(
            padding: const EdgeInsets.all(8), // 缩小内边距
            child: _selectedMode == 'health_zones' 
                ? _buildHealthZonesLegend()
                : _buildSafeRoutesLegend(),
          ),
        ],
      ),
    );
  }

  // 健康区域图例
  Widget _buildHealthZonesLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Zones',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11), // 缩小字体
        ),
        const SizedBox(height: 6),
        
        // 优秀区域 (绿色)
        _buildLegendItem(
          color: const Color(0xFF4CAF50),
          icon: Icons.park,
          title: 'Excellent',
          description: 'Parks',
        ),
        
        // 良好区域 (浅绿色)
        _buildLegendItem(
          color: const Color(0xFF8BC34A),
          icon: Icons.home,
          title: 'Good',
          description: 'Residential',
        ),
        
        // 一般区域 (黄色)
        _buildLegendItem(
          color: const Color(0xFFFFEB3B),
          icon: Icons.location_city,
          title: 'Moderate',
          description: 'Mixed Use',
        ),
        
        // 较差区域 (橙色)
        _buildLegendItem(
          color: const Color(0xFFFF9800),
          icon: Icons.business,
          title: 'Poor',
          description: 'Commercial',
        ),
        
        // 差区域 (红色)
        _buildLegendItem(
          color: const Color(0xFFF44336),
          icon: Icons.traffic,
          title: 'Very Poor',
          description: 'High Traffic',
        ),
        
        const SizedBox(height: 4),
        
        // 说明 - 缩小
        Row(
          children: [
            Icon(Icons.info_outline, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Tap zones for details',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 安全路线图例
  Widget _buildSafeRoutesLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Safe Routes',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11), // 缩小字体
        ),
        const SizedBox(height: 6),
        
        // 推荐路线 (绿色)
        _buildRouteLegendItem(
          color: const Color(0xFF4CAF50),
          icon: Icons.directions_walk,
          title: 'Recommended',
          description: 'Clean air',
        ),
        
        // 可选路线 (黄色)
        _buildRouteLegendItem(
          color: const Color(0xFFFFEB3B),
          icon: Icons.directions_bike,
          title: 'Optional',
          description: 'Moderate',
        ),
        
        // 谨慎路线 (橙色)
        _buildRouteLegendItem(
          color: const Color(0xFFFF9800),
          icon: Icons.commute,
          title: 'Caution',
          description: 'Higher pollution',
        ),
        
        // 不推荐路线 (红色)
        _buildRouteLegendItem(
          color: const Color(0xFFF44336),
          icon: Icons.warning,
          title: 'Not Recommended',
          description: 'Heavy traffic',
        ),
        
        const SizedBox(height: 4),
        
        // 说明 - 缩小
        Row(
          children: [
            Icon(Icons.info_outline, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Tap routes for details',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 图例项目组件
  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3), // 缩小间距
      child: Row(
        children: [
          // 颜色圆圈 - 缩小
          Container(
            width: 12, // 缩小尺寸
            height: 12,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              border: Border.all(color: color, width: 1.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 7, color: color), // 缩小图标
          ),
          const SizedBox(width: 6),
          
          // 文字说明 - 缩小
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10, // 缩小字体
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 8, // 缩小字体
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 路线图例项目组件
  Widget _buildRouteLegendItem({
    required Color color,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3), // 缩小间距
      child: Row(
        children: [
          // 颜色线条 - 缩小
          Container(
            width: 16, // 缩小宽度
            height: 3, // 缩小高度
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 6),
          
          // 图标 - 缩小
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          
          // 文字说明 - 缩小
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10, // 缩小字体
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 8, // 缩小字体
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 路线类型图例
  Widget _buildRouteTypeLegend(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environmental Health Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadHealthData,
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
              initialZoom: _currentZoom,
              minZoom: 10,
              maxZoom: 18,
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
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.cityzen',
              ),
              
              // 健康区域层
              if (_selectedMode == 'health_zones')
                CircleLayer(
                  circles: _healthZones.map((zone) => CircleMarker(
                    point: zone.center,
                    color: zone.color.withOpacity(0.3),
                    borderColor: zone.color,
                    borderStrokeWidth: 2,
                    radius: zone.radius / 10, // 调整显示半径
                  )).toList(),
                ),
              
              // 安全路线层
              if (_selectedMode == 'safe_routes')
                PolylineLayer(
                  polylines: _safeRoutes.map((route) => Polyline(
                    points: route.points,
                    color: route.routeColor,
                    strokeWidth: 4.0,
                  )).toList(),
                ),
              
              // 标记层
              MarkerLayer(
                markers: [
                  // 中心点标记
                  Marker(
                    point: _center,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
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
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  
                  // 健康区域标记
                  if (_selectedMode == 'health_zones')
                    ..._healthZones.map((zone) => Marker(
                      point: zone.center,
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showZoneDetails(zone),
                        child: Container(
                          decoration: BoxDecoration(
                            color: zone.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            zone.typeIcon,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    )),
                  
                  // 路线起点标记
                  if (_selectedMode == 'safe_routes')
                    ..._safeRoutes.map((route) => Marker(
                      point: route.points.first,
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showRouteDetails(route),
                        child: Container(
                          decoration: BoxDecoration(
                            color: route.routeColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            route.typeIcon,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    )),
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
                        Text('Loading health data...'),
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

          // 模式选择器
          Positioned(
            top: 16,
            left: 16,
            child: _buildModeSelector(),
          ),

          // 信息面板
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: _buildInfoPanel(),
          ),

          // 图例面板 - 移到更靠下的位置，避免压盖
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildLegendPanel(),
          ),

          // 定位按钮
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'location',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () async {
                try {
                  final position = await Geolocator.getCurrentPosition();
                  final userLocation = LatLng(position.latitude, position.longitude);
                  
                  setState(() {
                    _center = userLocation;
                    _currentCenter = userLocation;
                  });
                  
                  _mapController.move(userLocation, _currentZoom);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to get location: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}