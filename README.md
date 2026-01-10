# CityZen

一个智能环境健康助手应用，帮助城市居民了解实时环境状况，做出明智的日常生活决策，减少环境暴露风险。

## 应用定位

CityZen专为意大利米兰等欧洲高污染城市设计，考虑到老年化社会现实，专注于：
- 日常环境暴露风险评估
- 外出时间和路线建议
- 室内外活动选择指导
- 健康防护措施提醒

## 功能特色

### 🏠 首页
- 实时天气和空气质量监测
- 基于环境条件的智能生活建议
- 美观的天气可视化和趋势图表

### 🗺️ 地图
- 交互式环境数据地图（AQI、PM2.5、臭氧、降水）
- 附近公园和绿地发现
- 基于位置的环境洞察

### 🤖 AI助手
- 基于Google Gemini的环境健康智能助手
- 个性化的日常活动建议
- 环境暴露风险评估
- 与AI助手的交互式对话

### ⚙️ 设置
- 多AI提供商支持（Gemini、OpenAI、Claude）
- 可定制的健康阈值和偏好设置
- 位置服务和单位偏好

## 技术栈

- **Flutter** - 跨平台移动框架
- **Google Gemini AI** - 智能建议系统
- **OpenMeteo API** - 天气和空气质量数据
- **OpenStreetMap** - 地图和位置服务
- **Flutter Map** - 交互式地图可视化
- **FL Chart** - 数据可视化

## 快速开始

1. 克隆仓库
2. 安装依赖：`flutter pub get`
3. 配置AI服务（可选）：在设置中添加您的API密钥
4. 运行应用：`flutter run`

## 环境数据API

- 天气数据：[Open-Meteo](https://open-meteo.com/)
- 空气质量：[Open-Meteo Air Quality API](https://open-meteo.com/en/docs/air-quality-api)
- 公园数据：[Overpass API](https://overpass-api.de/) (OpenStreetMap)

## 许可证

本项目采用MIT许可证。
