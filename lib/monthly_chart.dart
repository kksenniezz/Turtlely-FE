import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'style.dart';

class MonthlyChartWidget extends StatefulWidget {
  final List<double> cvaData;
  final List<double> craData;
  final List<String> months;
  final String? currentMonth;

  const MonthlyChartWidget({
    super.key,
    required this.cvaData,
    required this.craData,
    required this.months,
    this.currentMonth,
  });

  @override
  State<MonthlyChartWidget> createState() => _MonthlyChartWidgetState();
}

class _MonthlyChartWidgetState extends State<MonthlyChartWidget> {
  // 각각 CVA, CRA 차트에서 현재 고정된 터치 인덱스를 관리 (null이면 고정 안 됨)
  int? _selectedCvaIndex;
  int? _selectedCraIndex;

  @override
  Widget build(BuildContext context) {
    return _buildChartFrame("CVA / CRA 각도 변화 그래프");
  }

  Widget _buildChartFrame(String title) {
    int startIndex = 0;
    if (widget.currentMonth != null && widget.currentMonth!.isNotEmpty) {
      final targetIdx = widget.months.indexOf(widget.currentMonth!);
      if (targetIdx != -1) {
        startIndex = targetIdx;
      }
    }

    final slicedCva = widget.cvaData.sublist(startIndex);
    final slicedCra = widget.craData.sublist(startIndex);
    final slicedMonths = widget.months.sublist(startIndex);

    final count = slicedMonths.length > 6 ? 6 : slicedMonths.length;
    final limitedCva = slicedCva.sublist(0, count);
    final limitedCra = slicedCra.sublist(0, count);
    final limitedMonths = slicedMonths.sublist(0, count);

    final reversedCva = limitedCva.reversed.toList();
    final reversedCra = limitedCra.reversed.toList();
    final reversedMonths = limitedMonths.reversed.toList();

    final validIndices = List.generate(
      reversedCva.length,
      (i) => (reversedCva[i] != -1 && reversedCra[i] != -1) ? i : -1,
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
          reversedCva,
          reversedMonths,
          50.0,
          48.7,
          TColor.buttonGreen,
          validIndices,
          _selectedCvaIndex,
          (index) {
            setState(() {
              if (_selectedCvaIndex == index) {
                _selectedCvaIndex = null;
              } else {
                _selectedCvaIndex = index;
              }
            });
          },
        ),
        const SizedBox(height: 16),
        _buildSingleChartBox(
          "CRA",
          reversedCra,
          reversedMonths,
          145.0,
          145.0,
          TColor.buttonGreen,
          validIndices,
          _selectedCraIndex,
          (index) {
            setState(() {
              if (_selectedCraIndex == index) {
                _selectedCraIndex = null;
              } else {
                _selectedCraIndex = index;
              }
            });
          },
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
    List<String> chartMonths,
    double chartCenter,
    double standardAngle,
    Color color,
    List<int> validIndices,
    int? selectedIndex,
    Function(int?) onSelectedIndexChanged,
  ) {
    final double minBound = chartCenter - 25;
    final double maxBound = chartCenter + 25;

    final List<Map<String, dynamic>> processedSpots = [];
    for (int i = 0; i < validIndices.length; i++) {
      int originalIdx = validIndices[i];
      double rawValue = data[originalIdx];
      processedSpots.add({
        'x': i.toDouble(),
        'y': rawValue.clamp(minBound, maxBound),
        'realY': rawValue,
        'isOutOfRange': rawValue < minBound || rawValue > maxBound,
      });
    }

    if (processedSpots.isEmpty) {
      return const SizedBox();
    }

    List<ShowingTooltipIndicators> showingTooltipSpots = [];
    if (selectedIndex != null) {
      Map<String, dynamic>? spotItem;
      for (var item in processedSpots) {
        if (item['x'] == selectedIndex.toDouble()) {
          spotItem = item;
          break;
        }
      }

      if (spotItem != null &&
          spotItem.containsKey('x') &&
          spotItem.containsKey('y')) {
        final double xVal = (spotItem['x'] as num).toDouble();
        final double yVal = (spotItem['y'] as num).toDouble();

        showingTooltipSpots.add(
          ShowingTooltipIndicators([
            LineBarSpot(
              LineChartBarData(spots: [FlSpot(xVal, yVal)]),
              0,
              FlSpot(xVal, yVal),
            ),
          ]),
        );
      }
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
                  maxX: (data.length > 6 ? data.length - 1 : 5).toDouble(),
                  showingTooltipIndicators: showingTooltipSpots,
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
                              index >= chartMonths.length ||
                              index >= data.length) {
                            return const SizedBox();
                          }
                          return Text(
                            chartMonths[index],
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
                    handleBuiltInTouches: false,
                    touchCallback:
                        (FlTouchEvent event, LineTouchResponse? response) {
                          if (event is FlTapUpEvent) {
                            if (response != null &&
                                response.lineBarSpots != null &&
                                response.lineBarSpots!.isNotEmpty) {
                              final spotIndex =
                                  response.lineBarSpots!.first.spotIndex;
                              onSelectedIndexChanged(spotIndex);
                            } else {
                              onSelectedIndexChanged(null);
                            }
                          }
                        },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      tooltipBorder: const BorderSide(
                        color: TColor.buttonGreen,
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final matchedSpot = processedSpots.firstWhere(
                            (e) => e['x'] == spot.x,
                            orElse: () => processedSpots.first,
                          );
                          final realValue = matchedSpot['realY'];
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
