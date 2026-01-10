# 空气质量数据细化改进方案

## 🎯 **改进目标**

将当前的单点、静态空气质量数据升级为**高分辨率、多时空尺度**的智能环境监测系统。

## 📊 **当前问题**

### 空间分辨率不足
- **单点数据**：只有用户当前位置的数据
- **11km网格**：OpenMeteo空气质量数据分辨率较粗
- **缺乏区域对比**：无法比较不同区域的空气质量

### 时间分辨率不足
- **静态快照**：只显示当前时刻
- **缺乏预测**：没有未来趋势预报
- **简单趋势**：历史数据展示有限

## 🔧 **技术改进方案**

### 1. **多数据源集成**

#### A. 高分辨率空气质量API
```dart
// 集成多个高精度空气质量数据源
class EnhancedAirQualityService {
  // 1. OpenAQ - 全球空气质量监测站数据 (1-5km精度)
  static const String openAQBaseUrl = 'https://api.openaq.org/v2';
  
  // 2. PurpleAir - 众包传感器网络 (街道级精度)
  static const String purpleAirBaseUrl = 'https://api.purpleair.com/v1';
  
  // 3. WAQI - 世界空气质量指数 (城市级高精度)
  static const String waqiBaseUrl = 'https://api.waqi.info';
  
  // 4. 欧洲环境署 - 欧洲地区高精度数据
  static const String eeaBaseUrl = 'https://discomap.eea.europa.eu/map/fme/AirQualityExport.fmw';
}
```

#### B. 空间插值算法
```dart
class SpatialInterpolation {
  // 使用反距离权重插值 (IDW) 提高空间分辨率
  static double interpolateIDW(
    List<AirQualityPoint> nearbyStations,
    LatLng targetLocation,
    {double power = 2.0}
  ) {
    double weightedSum = 0.0;
    double weightSum = 0.0;
    
    for (final station in nearbyStations) {
      final distance = _calculateDistance(station.location, targetLocation);
      if (distance < 0.001) return station.value; // 非常接近的站点
      
      final weight = 1.0 / math.pow(distance, power);
      weightedSum += station.value * weight;
      weightSum += weight;
    }
    
    return weightedSum / weightSum;
  }
  
  // 克里金插值 - 更高级的空间插值方法
  static double interpolateKriging(
    List<AirQualityPoint> stations,
    LatLng target
  ) {
    // 实现克里金插值算法
    // 考虑空间自相关性，提供更准确的插值结果
  }
}
```

### 2. **时空数据模型**

#### A. 多时间尺度数据结构
```dart
class TimeSeriesAirQuality {
  final String pollutant; // PM2.5, PM10, O3, NO2, SO2
  final LatLng location;
  final List<TimePoint> hourlyData;    // 过去24小时
  final List<TimePoint> dailyData;     // 过去30天
  final List<TimePoint> forecastData;  // 未来48小时预测
  
  // 获取特定时间的插值数据
  double getValueAtTime(DateTime time) {
    // 时间插值算法
  }
  
  // 获取时间段内的统计信息
  AirQualityStats getStatsForPeriod(DateTime start, DateTime end) {
    return AirQualityStats(
      mean: _calculateMean(start, end),
      max: _calculateMax(start, end),
      min: _calculateMin(start, end),
      trend: _calculateTrend(start, end),
    );
  }
}

class TimePoint {
  final DateTime timestamp;
  final double value;
  final double confidence; // 数据置信度
  final String source;     // 数据来源
  
  const TimePoint({
    required this.timestamp,
    required this.value,
    required this.confidence,
    required this.source,
  });
}
```

#### B. 空间网格数据
```dart
class AirQualityGrid {
  final double resolution; // 网格分辨率 (km)
  final LatLngBounds bounds;
  final Map<String, List<List<double>>> pollutantGrids;
  final DateTime timestamp;
  
  // 获取指定位置的插值数据
  double getInterpolatedValue(LatLng location, String pollutant) {
    final gridCoords = _locationToGrid(location);
    return _bilinearInterpolation(gridCoords, pollutant);
  }
  
  // 双线性插值
  double _bilinearInterpolation(GridCoords coords, String pollutant) {
    final grid = pollutantGrids[pollutant]!;
    // 实现双线性插值算法
  }
}
```

### 3. **增强的API集成**

#### A. 多源数据获取
```dart
class MultiSourceAirQualityService {
  Future<EnhancedAirQualityData> getEnhancedData(LatLng location) async {
    // 并行请求多个数据源
    final futures = await Future.wait([
      _getOpenAQData(location),
      _getPurpleAirData(location),
      _getWAQIData(location),
      _getOpenMeteoData(location),
    ]);
    
    // 数据融合和质量控制
    return _fuseDataSources(futures);
  }
  
  Future<List<AirQualityStation>> _getNearbyStations(
    LatLng location, 
    double radiusKm
  ) async {
    // 获取指定半径内的所有监测站
    final openAQStations = await _getOpenAQStations(location, radiusKm);
    final purpleAirStations = await _getPurpleAirStations(location, radiusKm);
    
    return [...openAQStations, ...purpleAirStations];
  }
  
  EnhancedAirQualityData _fuseDataSources(List<dynamic> sources) {
    // 数据融合算法
    // 1. 数据质量评估
    // 2. 权重分配
    // 3. 异常值检测和剔除
    // 4. 不确定性量化
  }
}
```

#### B. 预测模型集成
```dart
class AirQualityForecast {
  // 集成机器学习预测模型
  Future<List<ForecastPoint>> getForecast(
    LatLng location, 
    int hoursAhead
  ) async {
    // 1. 获取历史数据
    final historicalData = await _getHistoricalData(location, days: 30);
    
    // 2. 获取气象预报数据
    final weatherForecast = await _getWeatherForecast(location, hoursAhead);
    
    // 3. 应用预测模型
    return _applyForecastModel(historicalData, weatherForecast);
  }
  
  List<ForecastPoint> _applyForecastModel(
    List<HistoricalPoint> history,
    List<WeatherPoint> weather
  ) {
    // 简化的线性回归模型
    // 实际应用中可以使用更复杂的ML模型
    // 如LSTM、Random Forest等
  }
}
```

### 4. **UI/UX 改进**

#### A. 高分辨率地图可视化
```dart
class AirQualityHeatmapLayer extends StatelessWidget {
  final AirQualityGrid grid;
  final String pollutant;
  
  @override
  Widget build(BuildContext context) {
    return HeatmapLayer(
      heatmapDataSet: HeatmapDataSet(
        data: _gridToHeatmapData(grid, pollutant),
      ),
      heatmapOptions: HeatmapOptions(
        radius: 50,
        minOpacity: 0.1,
        maxOpacity: 0.8,
        gradient: _getPollutantGradient(pollutant),
        blur: 15,
      ),
    );
  }
  
  Map<double, Color> _getPollutantGradient(String pollutant) {
    switch (pollutant) {
      case 'PM2.5':
        return {
          0.0: Colors.green,
          0.2: Colors.yellow,
          0.5: Colors.orange,
          0.8: Colors.red,
          1.0: Colors.purple,
        };
      // 其他污染物的颜色映射
    }
  }
}
```

#### B. 时间序列可视化
```dart
class TimeSeriesChart extends StatelessWidget {
  final TimeSeriesAirQuality data;
  
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          // 历史数据线
          _buildHistoricalLine(),
          // 预测数据线 (虚线)
          _buildForecastLine(),
          // 置信区间
          _buildConfidenceInterval(),
        ],
        titlesData: _buildTimeAxisTitles(),
        gridData: _buildGridData(),
      ),
    );
  }
}
```

#### C. 多尺度空间选择
```dart
class SpatialScaleSelector extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 空间尺度选择器
        SegmentedButton<SpatialScale>(
          segments: [
            ButtonSegment(
              value: SpatialScale.neighborhood,
              label: Text('街区级'),
              icon: Icon(Icons.location_city),
            ),
            ButtonSegment(
              value: SpatialScale.city,
              label: Text('城市级'),
              icon: Icon(Icons.location_on),
            ),
            ButtonSegment(
              value: SpatialScale.region,
              label: Text('区域级'),
              icon: Icon(Icons.public),
            ),
          ],
          selected: {_selectedScale},
          onSelectionChanged: _onScaleChanged,
        ),
        
        // 时间尺度选择器
        SegmentedButton<TimeScale>(
          segments: [
            ButtonSegment(
              value: TimeScale.hourly,
              label: Text('小时'),
            ),
            ButtonSegment(
              value: TimeScale.daily,
              label: Text('日'),
            ),
            ButtonSegment(
              value: TimeScale.weekly,
              label: Text('周'),
            ),
          ],
          selected: {_selectedTimeScale},
          onSelectionChanged: _onTimeScaleChanged,
        ),
      ],
    );
  }
}
```

### 5. **智能分析功能**

#### A. 空间热点识别
```dart
class AirQualityHotspotAnalyzer {
  List<Hotspot> identifyHotspots(AirQualityGrid grid, String pollutant) {
    final hotspots = <Hotspot>[];
    
    // 使用聚类算法识别污染热点
    final clusters = _performClustering(grid, pollutant);
    
    for (final cluster in clusters) {
      if (cluster.averageValue > _getThreshold(pollutant)) {
        hotspots.add(Hotspot(
          center: cluster.center,
          radius: cluster.radius,
          intensity: cluster.averageValue,
          pollutant: pollutant,
          riskLevel: _calculateRiskLevel(cluster.averageValue, pollutant),
        ));
      }
    }
    
    return hotspots;
  }
}
```

#### B. 个性化路线推荐
```dart
class CleanAirRouteOptimizer {
  Future<List<LatLng>> findCleanestRoute(
    LatLng start,
    LatLng end,
    String activityType
  ) async {
    // 获取路径上的空气质量数据
    final airQualityGrid = await _getAirQualityGrid(start, end);
    
    // 使用A*算法，以空气质量为权重
    return _findOptimalPath(start, end, airQualityGrid, activityType);
  }
  
  double _calculatePathCost(
    LatLng from,
    LatLng to,
    AirQualityGrid grid,
    String activityType
  ) {
    final distance = _calculateDistance(from, to);
    final airQuality = grid.getInterpolatedValue(to, 'PM2.5');
    final activityWeight = _getActivityWeight(activityType);
    
    // 综合考虑距离和空气质量
    return distance + (airQuality * activityWeight);
  }
}
```

## 📱 **实施计划**

### 阶段1：数据源扩展 (1-2周)
1. 集成OpenAQ API
2. 添加PurpleAir数据源
3. 实现基础数据融合

### 阶段2：空间插值 (1周)
1. 实现IDW插值算法
2. 添加网格化数据结构
3. 优化地图可视化

### 阶段3：时间序列增强 (1周)
1. 扩展历史数据存储
2. 添加预测功能
3. 改进图表展示

### 阶段4：智能分析 (1-2周)
1. 热点识别算法
2. 路线优化功能
3. 个性化推荐增强

## 🎯 **预期效果**

### 空间分辨率提升
- **从11km → 1-5km**：提高空间精度
- **街道级数据**：PurpleAir传感器网络
- **实时插值**：动态生成高分辨率数据

### 时间分辨率提升
- **历史趋势**：30天详细历史数据
- **预测功能**：48小时空气质量预报
- **实时更新**：15分钟数据刷新

### 用户体验提升
- **精准建议**：基于高精度数据的个性化推荐
- **路线优化**：避开污染热点的智能路径规划
- **风险预警**：提前预警空气质量恶化

## 💡 **技术创新点**

1. **多源数据融合**：结合官方监测站和众包传感器数据
2. **时空插值算法**：提供连续的时空空气质量场
3. **机器学习预测**：基于历史数据和气象条件的智能预测
4. **个性化优化**：根据活动类型和个人敏感度的定制化建议

这个改进方案将使CityZen从一个基础的环境监测应用升级为**专业级的空气质量分析平台**，为用户提供更精准、更智能的健康指导。