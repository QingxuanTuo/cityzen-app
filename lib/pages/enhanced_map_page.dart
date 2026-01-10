import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/enhanced_air_quality_service.dart';
import '../widgets/air_quality_heatmap.dart';

// 增强版地图页面 - 展示高分辨率空气质量数据
class EnhancedMapPage extends StatefulWidget {
  const EnhancedMapPage({Key? key}) : super(key: key);

  @override
  State<EnhancedMapPage> createState() => _EnhancedMapPageState();
}

class _EnhancedMapPageState extends State<EnhancedMapPage> {
  final MapController _mapController = MapController();
  final EnhancedAirQualityService _airQualityService = EnhancedAirQualityService();
  
  String _selectedPollutant = 'PM2.5';
  bool _showHeatmap = true;
  bool _showStations = true;
  bool _loading = false;
  
  // 数据
  AirQualityGrid? _airQualityGrid;
  List<AirQualityStation> _stations = [];
  InterpolatedAirQuality? _currentLocationData;
  
  // 地图中心和边界
  LatLng _center = const LatLng(45.4642, 9.1900); // 米兰
  double _currentZoom = 12.0;
  
  @override
  void initState() {
    super.initState();
    _loadAirQualityData();
  }
  
  Future<void> _loadAirQualityData() async {
    setState(() => _loading = true);
    
    try {
      // 1. 获取当前位置的插值数据
      final currentData = await _airQualityService.getInterpolatedAirQuality(
        _center, 
        10.0, // 10km半径
      );
      
      // 2. 获取附近的监测站
      final stations = await _airQualityService.getNearbyStations(
        _center, 
        20.0, // 20km半径
      );
      
      // 3. 生成网格数据（用于热力图）
      final bounds = LatLngBounds(
        LatLng(_center.latitude - 0.1, _center.longitude - 0.1),
        LatLng(_center.latitude + 0.1, _center.longitude + 0.1),
      );
      
      final grid = await _airQualityService.getAirQualityGrid(
        bounds, 
        2.0, // 2km网格分辨率
      );
      
      if (mounted) {
        setState(() {
          _currentLocationData = currentData;
          _stations = stations;
          _airQualityGrid = grid;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading air quality data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
  
  void _onStationTap(AirQualityStation station) {
    showDialog(
      context: context,
      builder: (context) => StationDetailDialog(station: station),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高分辨率空气质量'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAirQualityData,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 地图
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _currentZoom,
              minZoom: 8,
              maxZoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (position.zoom != null) _currentZoom = position.zoom!;
                if (position.center != null) _center = position.center!;
              },
            ),
            children: [
              // 地图瓦片
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.cityzen',
              ),
              
              // 热力图层
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
                  onStationTap: _onStationTap,
                ),
              
              // 当前位置标记
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // 控制面板
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildControlPanel(),
          ),
          
          // 图例
          Positioned(
            bottom: 100,
            left: 16,
            child: AirQualityLegend(pollutant: _selectedPollutant),
          ),
          
          // 当前位置数据显示
          if (_currentLocationData != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildCurrentDataCard(),
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
                        Text('加载高分辨率空气质量数据...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 污染物选择
            Row(
              children: [
                const Text('污染物: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'PM2.5', label: Text('PM2.5')),
                      ButtonSegment(value: 'PM10', label: Text('PM10')),
                      ButtonSegment(value: 'O3', label: Text('O₃')),
                    ],
                    selected: {_selectedPollutant},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedPollutant = selection.first);
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 显示选项
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('热力图'),
                    value: _showHeatmap,
                    onChanged: (value) => setState(() => _showHeatmap = value ?? true),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('监测站'),
                    value: _showStations,
                    onChanged: (value) => setState(() => _showStations = value ?? true),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCurrentDataCard() {
    final data = _currentLocationData!;
    final value = _getValueForPollutant(data, _selectedPollutant);
    final unit = _getUnitForPollutant(_selectedPollutant);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '当前位置空气质量',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(data.confidence),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '置信度: ${(data.confidence * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Text(
                  '$_selectedPollutant: ',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  value != null ? '${value.toStringAsFixed(1)} $unit' : '无数据',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: value != null ? _getColorForValue(value) : Colors.grey,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            
            Text(
              '基于 ${data.sourceStations.length} 个监测站的插值结果',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            
            Text(
              '插值方法: ${data.interpolationMethod}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  
  double? _getValueForPollutant(InterpolatedAirQuality data, String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
        return data.pm25;
      case 'PM10':
        return data.pm10;
      case 'O3':
        return data.ozone;
      default:
        return null;
    }
  }
  
  String _getUnitForPollutant(String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
      case 'PM10':
      case 'O3':
        return 'µg/m³';
      default:
        return '';
    }
  }
  
  Color _getColorForValue(double value) {
    // 简化的颜色映射
    if (value < 25) return Colors.green;
    if (value < 50) return Colors.yellow;
    if (value < 75) return Colors.orange;
    return Colors.red;
  }
  
  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return Colors.green;
    if (confidence > 0.6) return Colors.orange;
    return Colors.red;
  }
}