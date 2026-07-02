import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'style.dart';

class MonthlyChartWidget extends StatelessWidget {
  final List<double> cvaData;
  final List<double> craData;

  const MonthlyChartWidget({
    super.key,
    required this.cvaData,
    required this.craData,
  });

  @override
  Widget build(BuildContext context) {
    return _buildChartFrame("CVA / CRA 각도 변화 그래프");
  }

  Widget _buildChartFrame(String title) {
    // final List<double> cvaData = [52.0, 58.0, -1.0, 54.0, 51.0, 49.0];
    // final List<double> craData = [148.0, 142.0, 138.0, 136.0, -1.0, 135.0];

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
        const SizedBox(height: 16),
        _buildSingleChartBox(
          "CVA",
          cvaData,
          50.0,
          TColor.buttonGreen,
          validIndices,
        ),
        const SizedBox(height: 16),
        _buildSingleChartBox(
          "CRA",
          craData,
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
    double target,
    Color color,
    List<int> validIndices,
  ) {
    final List<FlSpot> spots = validIndices.asMap().entries.map((e) {
      int originalIdx = e.value;
      return FlSpot(e.key.toDouble(), data[originalIdx]);
    }).toList();

    if (spots.isEmpty) {
      return const SizedBox();
    }
    final int lastIdx = spots.length - 1;

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
                  minY: target - 10,
                  maxY: target + 10,
                  minX: 0,
                  maxX: cvaData.length - 1,
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
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (val, meta) => Text(
                          "${validIndices[val.toInt()] + 1}월",
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 5,
                        getTitlesWidget: (val, meta) => Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            "${val.toInt()}",
                            style: TextStyle(
                              color: (val == target)
                                  ? TColor.pink
                                  : Colors.grey,
                              fontSize: 9,
                            ),
                          ),
                        ),
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
                      spots: spots,
                      isCurved: false,
                      color: color,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: [
                        FlSpot(0, target),
                        FlSpot(lastIdx.toDouble(), target),
                      ],
                      color: TColor.pink,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchSpotThreshold: 40,
                    handleBuiltInTouches: true,

                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      tooltipBorder: const BorderSide(
                        color: TColor.buttonGreen,
                        width: 1.5,
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final isNormalAngle = spot.barIndex == 1;

                          return LineTooltipItem(
                            "${spot.y}°",
                            TextStyle(
                              color: isNormalAngle
                                  ? TColor.pink
                                  : TColor.buttonGreen,
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
class PredictionChartWidget extends StatelessWidget {
  final List<double> predictionData;
  final List<String> predictionMonths;

  const PredictionChartWidget({
    super.key,
    required this.predictionData,
    required this.predictionMonths,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "거북목 개선 예측",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  minX: 0,
                  maxX: (predictionData.length - 1).toDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    verticalInterval: 1,
                    horizontalInterval: 20,
                    getDrawingVerticalLine: (val) => FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    ),
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: Colors.grey.withOpacity(0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          final i = val.toInt();
                          if (i >= predictionMonths.length)
                            return const SizedBox();

                          return Text(
                            predictionMonths[i],
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 20,
                        getTitlesWidget: (val, meta) => Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            "${val.toInt()}점",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 9,
                            ),
                          ),
                        ),
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
                      spots: predictionData.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: false,
                      color: TColor.buttonGreen,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchSpotThreshold: 40,
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      tooltipBorder: const BorderSide(
                        color: TColor.buttonGreen,
                        width: 1.5,
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            "${(spot.y).toInt()}점",
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
