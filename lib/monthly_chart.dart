import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'style.dart';

class MonthlyChartWidget extends StatelessWidget {
  final List<double> cvaData;
  final List<double> craData;
  final List<String> months;

  const MonthlyChartWidget({
    super.key,
    required this.cvaData,
    required this.craData,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    return _buildChartFrame("CVA / CRA 각도 변화 그래프");
  }

  Widget _buildChartFrame(String title) {
    final validIndices = List.generate(
      cvaData.length,
      (i) => (cvaData[i] != -1 && craData[i] != -1) ? i : -1,
    )..removeWhere((e) => e == -1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          "그래프 위 측정 지점을 눌러 나의 각도를 확인해 보세요",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey, // 회색 글씨
          ),
        ),
        const SizedBox(height: 16),
        _buildSingleChartBox(
          "CVA",
          cvaData,
          50.0,
          48.7,
          TColor.buttonGreen,
          validIndices,
        ),
        const SizedBox(height: 16),
        _buildSingleChartBox(
          "CRA",
          craData,
          145.0,
          145.0,
          TColor.buttonGreen,
          validIndices,
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendItem(TColor.pink, "정상"),
        const SizedBox(width: 12),
        _legendItem(TColor.buttonGreen, "나의 각도"),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _buildSingleChartBox(
    String label,
    List<double> data,
    double chartCenter,
    double standardAngle,
    Color color,
    List<int> validIndices,
  ) {
    final double minBound = chartCenter - 25;
    final double maxBound = chartCenter + 25;

    final List<Map<String, dynamic>> processedSpots = validIndices.map((
      originalIdx,
    ) {
      double rawValue = data[originalIdx];
      return {
        'x': originalIdx.toDouble(),
        'y': rawValue.clamp(minBound, maxBound),
        'realY': rawValue,
        'isOutOfRange': rawValue < minBound || rawValue > maxBound,
      };
    }).toList();

    if (processedSpots.isEmpty) {
      return const SizedBox();
    }

    return Container(
      width: double.infinity,
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: const Color(0xFFFAFAFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadows: [
          const BoxShadow(
            color: Color(0x140D0A2C),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildLegend(),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: LineChart(
                LineChartData(
                  minY: minBound,
                  maxY: maxBound,
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    verticalInterval: 1,
                    horizontalInterval: 5,
                    getDrawingVerticalLine: (val) => FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    ),
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: standardAngle,
                        color: TColor.pink,
                        strokeWidth: 2,
                      ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          final index = val.toInt();
                          if (index < 0 ||
                              index >= months.length ||
                              index >= data.length) {
                            return const SizedBox();
                          }
                          return Text(
                            months[index],
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 5,
                        getTitlesWidget: (val, meta) {
                          final double diff = (val - standardAngle).abs();

                          if (diff >= 1.5) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                "${val.toInt()}",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 9,
                                ),
                              ),
                            );
                          }

                          final String labelText = (standardAngle % 1 == 0)
                              ? standardAngle.toInt().toString()
                              : standardAngle.toStringAsFixed(1);

                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Stack(
                              children: [
                                Text(
                                  "${val.toInt()}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 9,
                                  ),
                                ),
                                Container(
                                  color: Colors.white,
                                  child: Text(
                                    labelText,
                                    style: const TextStyle(
                                      color: TColor.pink,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: processedSpots
                          .map((e) => FlSpot(e['x'], e['y']))
                          .toList(), // clamp된 y값 사용
                      isCurved: false,
                      color: color,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          // 3. 범위를 벗어난 점은 투명도 적용
                          final bool isOut =
                              processedSpots[index]['isOutOfRange'];
                          return FlDotCirclePainter(
                            radius: 6,
                            color: isOut ? color.withOpacity(0.3) : color,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchSpotThreshold: 50,
                    handleBuiltInTouches: true,

                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      tooltipBorder: const BorderSide(
                        color: TColor.buttonGreen,
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          // 원본 realY를 사용하여 툴팁 표시
                          final realValue =
                              processedSpots[spot.spotIndex]['realY'];
                          return LineTooltipItem(
                            "${realValue.toStringAsFixed(1)}°",
                            const TextStyle(
                              color: TColor.buttonGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 거북목 개선 예측 차트 -> 스트레칭 스켈레톤 이후 추가
// class PredictionChartWidget extends StatelessWidget {
//   final List<double> predictionScores;
//   final List<String> predictionMonths;

//   const PredictionChartWidget({
//     super.key,
//     required this.predictionScores,
//     required this.predictionMonths,
//   });

//   @override
//   Widget build(BuildContext context) {
//     print("🔍 예측 차트 데이터 확인");
//     print("개월 데이터: $predictionMonths");
//     print("점수 데이터: $predictionScores");
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.grey.shade200),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "거북목 개선 예측",
//             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             height: 240,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 20.0),
//               child: LineChart(
//                 LineChartData(
//                   minY: 0,
//                   maxY: 100,
//                   minX: 0,
//                   maxX: (predictionScores.length - 1).toDouble(),
//                   gridData: FlGridData(
//                     show: true,
//                     drawVerticalLine: true,
//                     drawHorizontalLine: true,
//                     verticalInterval: 1,
//                     horizontalInterval: 20,
//                     getDrawingVerticalLine: (val) => FlLine(
//                       color: Colors.grey.withOpacity(0.3),
//                       strokeWidth: 1,
//                     ),
//                     getDrawingHorizontalLine: (val) => FlLine(
//                       color: Colors.grey.withOpacity(0.3),
//                       strokeWidth: 1,
//                     ),
//                   ),
//                   titlesData: FlTitlesData(
//                     bottomTitles: AxisTitles(
//                       sideTitles: SideTitles(
//                         showTitles: true,
//                         interval: 1,
//                         getTitlesWidget: (val, meta) {
//                           final i = val.toInt();
//                           if (i >= predictionMonths.length) {
//                             return const SizedBox();
//                           }

//                           return Text(
//                             predictionMonths[i],
//                             style: const TextStyle(fontSize: 9, color: Colors.grey,),
//                           );
//                         },
//                       ),
//                     ),
//                     rightTitles: AxisTitles(
//                       sideTitles: SideTitles(
//                         showTitles: true,
//                         reservedSize: 40,
//                         interval: 20,
//                         getTitlesWidget: (val, meta) => Padding(
//                           padding: const EdgeInsets.only(left: 8.0),
//                           child: Text(
//                             "${val.toInt()}점",
//                             style: const TextStyle(
//                               color: Colors.grey,
//                               fontSize: 9,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                     leftTitles: AxisTitles(
//                       sideTitles: SideTitles(showTitles: false),
//                     ),
//                     topTitles: AxisTitles(
//                       sideTitles: SideTitles(showTitles: false),
//                     ),
//                   ),
//                   borderData: FlBorderData(
//                     show: true,
//                     border: Border.all(color: Colors.grey.withOpacity(0.3)),
//                   ),
//                   lineBarsData: [
//                     LineChartBarData(
//                       spots: predictionScores.asMap().entries.map((e) {
//                         return FlSpot(e.key.toDouble(), e.value);
//                       }).toList(),
//                       isCurved: false,
//                       color: TColor.buttonGreen,
//                       barWidth: 3,
//                       dotData: FlDotData(show: true),
//                     ),
//                   ],
//                   lineTouchData: LineTouchData(
//                     enabled: true,
//                     touchSpotThreshold: 40,
//                     handleBuiltInTouches: true,
//                     touchTooltipData: LineTouchTooltipData(
//                       getTooltipColor: (_) => Colors.white,
//                       tooltipBorder: const BorderSide(
//                         color: TColor.buttonGreen,
//                         width: 1.5,
//                       ),
//                       getTooltipItems: (touchedSpots) {
//                         return touchedSpots.map((spot) {
//                           return LineTooltipItem(
//                             "${(spot.y).toInt()}점",
//                             const TextStyle(
//                               color: TColor.buttonGreen,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           );
//                         }).toList();
//                       },
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
