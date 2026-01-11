import 'package:flutter/material.dart';
import 'package:cityzen/services/health_score_service.dart';
import 'package:cityzen/theme/app_theme.dart';

class HealthScoreCard extends StatelessWidget {
  final int score;
  final String advice;
  final Map<String, dynamic>? detailedAnalysis;
  final VoidCallback? onTap;

  const HealthScoreCard({
    super.key,
    required this.score,
    required this.advice,
    this.detailedAnalysis,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final healthService = HealthScoreService.instance;
    final scoreColor = healthService.getScoreColor(score);
    final scoreDescription = healthService.getScoreDescription(score);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scoreColor.withOpacity(0.1),
                scoreColor.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: scoreColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: scoreColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Environmental Health Score',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 评分显示
              Row(
                children: [
                  // 圆形进度指示器
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      children: [
                        // 背景圆环
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(Colors.grey[200]!),
                          ),
                        ),
                        // 进度圆环
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 8,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation(scoreColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        // 中心分数
                        Positioned.fill(
                          child: Center(
                            child: Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: scoreColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 20),
                  
                  // 评分信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 评分等级
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scoreColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: scoreColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            scoreDescription,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: scoreColor,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // 建议文本
                        Text(
                          advice,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // 详细分析（如果有）
              if (detailedAnalysis != null) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildFactorsPreview(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFactorsPreview() {
    if (detailedAnalysis == null || detailedAnalysis!['factors'] == null) {
      return const SizedBox.shrink();
    }

    final factors = detailedAnalysis!['factors'] as Map<String, dynamic>;
    final List<Widget> factorWidgets = [];

    // 显示前3个主要因子
    int count = 0;
    factors.forEach((key, value) {
      if (count >= 3) return;
      
      final factorData = value as Map<String, dynamic>;
      final status = factorData['status'] as String;
      final message = factorData['message'] as String;
      
      Color statusColor = _getStatusColor(status);
      IconData statusIcon = _getStatusIcon(key, status);
      
      factorWidgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: count < 2 ? 8 : 0),
          child: Row(
            children: [
              Icon(
                statusIcon,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
      count++;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Factors',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        ...factorWidgets,
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'good':
      case 'excellent':
        return Colors.green;
      case 'moderate':
        return Colors.amber;
      case 'poor':
      case 'very_poor':
        return Colors.red;
      case 'cold':
      case 'hot':
        return Colors.orange;
      case 'dry':
      case 'humid':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String factor, String status) {
    switch (factor) {
      case 'pm25':
      case 'pm10':
        return Icons.air;
      case 'temperature':
        return status == 'cold' ? Icons.ac_unit : 
               status == 'hot' ? Icons.wb_sunny : Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'windSpeed':
        return Icons.air;
      case 'weather':
        return Icons.wb_cloudy;
      default:
        return Icons.info_outline;
    }
  }
}

// 简化版健康评分卡片（用于较小空间）
class CompactHealthScoreCard extends StatelessWidget {
  final int score;
  final String description;
  final VoidCallback? onTap;

  const CompactHealthScoreCard({
    super.key,
    required this.score,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final healthService = HealthScoreService.instance;
    final scoreColor = healthService.getScoreColor(score);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scoreColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              // 小型圆形进度指示器
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(scoreColor),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Environmental Health',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }
}