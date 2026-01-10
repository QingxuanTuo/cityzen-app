# CityZen 应用 API 服务调用分析

## 📊 **服务概览**

CityZen应用当前集成了**8个主要外部服务**，涵盖天气、空气质量、地图、AI和地理数据。

## 🌤️ **1. 天气数据服务**

### **OpenMeteo Weather API**
- **API地址**: `https://api.open-meteo.com/v1/forecast`
- **服务商**: Open-Meteo (开源天气API)
- **费用**: 完全免费
- **调用频率**: 每30分钟自动刷新
- **数据内容**: 温度、风速、天气代码、湿度

#### **调用示例**:
```dart
final uri = Uri.parse(
  'https://api.open-meteo.com/v1/forecast'
  '?latitude=45.4642&longitude=9.1900'
  '&current=temperature_2m,wind_speed_10m,weathercode,relative_humidity_2m'
  '&timezone=auto'
);
```

#### **返回数据格式**:
```json
{
  "current": {
    "temperature_2m": 20.5,
    "wind_speed_10m": 12.3,
    "weathercode": 0,
    "relative_humidity_2m": 65
  }
}
```

## 🌬️ **2. 空气质量服务**

### **OpenMeteo Air Quality API**
- **API地址**: `https://air-quality-api.open-meteo.com/v1/air-quality`
- **服务商**: Open-Meteo
- **费用**: 完全免费
- **调用频率**: 每30分钟自动刷新
- **数据内容**: PM2.5, PM10, 臭氧

#### **调用示例**:
```dart
final aqUri = Uri.parse(
  'https://air-quality-api.open-meteo.com/v1/air-quality'
  '?latitude=45.4642&longitude=9.1900'
  '&hourly=pm10,pm2_5'
  '&current=pm2_5,pm10,ozone'
  '&timezone=auto'
);
```

### **OpenAQ API** (增强功能)
- **API地址**: `https://api.openaq.org/v2`
- **服务商**: OpenAQ (全球空气质量数据平台)
- **费用**: 免费 (有速率限制)
- **调用频率**: 按需调用
- **数据内容**: 全球监测站实时数据

#### **调用示例**:
```dart
final uri = Uri.parse(
  'https://api.openaq.org/v2/locations'
  '?coordinates=45.4642,9.1900'
  '&radius=20000'  // 20km半径
  '&limit=50'
  '&order_by=distance'
);
```

### **WAQI API** (世界空气质量指数)
- **API地址**: `https://api.waqi.info`
- **服务商**: World Air Quality Index
- **费用**: 免费版本 (需要API key)
- **调用频率**: 按需调用
- **数据内容**: AQI指数、多种污染物

#### **调用示例**:
```dart
final uri = Uri.parse(
  'https://api.waqi.info/map/bounds'
  '?latlng=45.4,9.1,45.5,9.2'
  '&token=YOUR_WAQI_TOKEN'
);
```

## 🗺️ **3. 地图服务**

### **CartoDB 地图瓦片**
- **API地址**: `https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png`
- **服务商**: CartoDB (现为CARTO)
- **费用**: 免费使用 (有使用限制)
- **调用频率**: 实时 (用户交互时)
- **数据内容**: 地图瓦片图像

#### **调用配置**:
```dart
TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
  subdomains: const ['a', 'b', 'c', 'd'],
  userAgentPackageName: 'com.example.cityzen',
)
```

### **Overpass API** (OpenStreetMap数据)
- **API地址**: 
  - `https://overpass-api.de/api/interpreter`
  - `https://lz4.overpass-api.de/api/interpreter`
  - `https://overpass.kumi.systems/api/interpreter`
- **服务商**: OpenStreetMap社区
- **费用**: 完全免费
- **调用频率**: 按需调用 (获取公园数据时)
- **数据内容**: 公园、绿地等地理信息

#### **调用示例**:
```dart
const query = '''
[out:json][timeout:12];
(
  node["leisure"="park"](around:2000,45.4642,9.1900);
  way["leisure"="park"](around:2000,45.4642,9.1900);
  relation["leisure"="park"](around:2000,45.4642,9.1900);
);
out center 30;
''';
```

## 🤖 **4. AI服务**

### **Google Gemini API**
- **API地址**: `https://generativelanguage.googleapis.com/v1beta/models`
- **服务商**: Google
- **费用**: 免费额度 + 付费计划
- **调用频率**: 用户交互时
- **数据内容**: AI对话和建议

#### **调用示例**:
```dart
final content = [Content.text(systemPrompt)];
final response = await _geminiModel!.generateContent(content);
```

### **OpenAI GPT API**
- **API地址**: `https://api.openai.com/v1/chat/completions`
- **服务商**: OpenAI
- **费用**: 付费服务
- **调用频率**: 用户交互时
- **数据内容**: AI对话和建议

#### **调用示例**:
```dart
final response = await http.post(
  Uri.parse('https://api.openai.com/v1/chat/completions'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  },
  body: jsonEncode({
    'model': 'gpt-4o-mini',
    'messages': [{'role': 'user', 'content': prompt}],
  }),
);
```

### **Anthropic Claude API**
- **API地址**: `https://api.anthropic.com/v1/messages`
- **服务商**: Anthropic
- **费用**: 付费服务
- **调用频率**: 用户交互时
- **数据内容**: AI对话和建议

#### **调用示例**:
```dart
final response = await http.post(
  Uri.parse('https://api.anthropic.com/v1/messages'),
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': apiKey,
    'anthropic-version': '2023-06-01',
  },
  body: jsonEncode({
    'model': 'claude-3-haiku-20240307',
    'max_tokens': 1000,
    'messages': [{'role': 'user', 'content': prompt}],
  }),
);
```

## 📍 **5. 地理编码服务**

### **Geolocator + Geocoding**
- **服务**: 设备GPS + 系统地理编码
- **费用**: 免费 (系统服务)
- **调用频率**: 按需调用
- **数据内容**: 经纬度坐标、城市名称

#### **调用示例**:
```dart
final position = await Geolocator.getCurrentPosition();
final placemarks = await placemarkFromCoordinates(
  position.latitude, 
  position.longitude
);
```

## 📊 **API调用统计**

### **调用频率分析**
| 服务类型 | 调用频率 | 每日估计调用次数 |
|---------|---------|----------------|
| 天气数据 | 每30分钟 | 48次 |
| 空气质量 | 每30分钟 | 48次 |
| 地图瓦片 | 实时交互 | 500-2000次 |
| 公园数据 | 位置变化时 | 5-10次 |
| AI服务 | 用户交互 | 10-50次 |
| 地理编码 | 应用启动 | 1-5次 |

### **费用分析**
| 服务 | 费用模式 | 月成本估算 |
|------|---------|-----------|
| OpenMeteo | 完全免费 | $0 |
| CartoDB | 免费额度 | $0 |
| Overpass | 完全免费 | $0 |
| OpenAQ | 免费 | $0 |
| Google Gemini | 免费额度+付费 | $0-5 |
| OpenAI GPT | 付费 | $5-20 |
| Claude | 付费 | $5-15 |
| 地理编码 | 系统服务 | $0 |

## 🔒 **API密钥管理**

### **需要API密钥的服务**
1. **Google Gemini**: 从 [Google AI Studio](https://aistudio.google.com) 获取
2. **OpenAI**: 从 [OpenAI Platform](https://platform.openai.com) 获取
3. **Claude**: 从 [Anthropic Console](https://console.anthropic.com) 获取
4. **WAQI**: 从 [WAQI](https://aqicn.org/api/) 获取 (可选)

### **无需API密钥的服务**
- OpenMeteo (天气和空气质量)
- CartoDB (地图瓦片)
- Overpass API (公园数据)
- OpenAQ (空气质量监测站)
- 系统地理编码服务

## 🚀 **性能优化**

### **缓存策略**
- **天气数据**: 30分钟本地缓存
- **空气质量**: 30分钟本地缓存
- **公园数据**: 24小时本地缓存
- **地图瓦片**: 系统自动缓存

### **错误处理**
- **超时设置**: 所有HTTP请求10秒超时
- **重试机制**: 失败时自动重试
- **降级策略**: API失败时使用缓存数据
- **多端点支持**: Overpass API有3个备用端点

### **网络优化**
- **并行请求**: 天气和空气质量数据并行获取
- **请求合并**: 相同位置的数据请求合并
- **数据压缩**: 使用gzip压缩减少流量

## 📈 **扩展计划**

### **计划添加的服务**
1. **PurpleAir API**: 众包空气质量传感器数据
2. **Weather Underground**: 更详细的天气预报
3. **NASA Air Quality**: 卫星空气质量数据
4. **Local Government APIs**: 各地政府环境数据

### **优化方向**
1. **GraphQL集成**: 减少数据传输量
2. **WebSocket连接**: 实时数据推送
3. **边缘计算**: CDN加速数据获取
4. **机器学习**: 本地数据预测模型

## 🔧 **开发者配置**

### **环境变量设置**
```dart
// 在应用设置中配置
const String GEMINI_API_KEY = 'your_gemini_key';
const String OPENAI_API_KEY = 'your_openai_key';
const String CLAUDE_API_KEY = 'your_claude_key';
```

### **调试模式**
```dart
// 启用API调用日志
debugPrint('API Call: $uri');
debugPrint('Response: ${response.body}');
```

这个全面的API分析展示了CityZen应用的技术架构和外部依赖，为进一步的优化和扩展提供了清晰的指导。