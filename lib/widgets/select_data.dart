import 'dart:io';
import 'package:flutter/material.dart';

class SelectDataCustom{

  Future<String?> showActivityDialog(BuildContext context, ) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20), // padding to screen edges
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.white,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Aktivität auswählen",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    splashColor: Colors.grey.shade200, // soft tap highlight
                    highlightColor: Colors.transparent,
                    onTap: () => Navigator.pop(context, "Run"),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Text(
                            "👟",
                            style: TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Lauf",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ]
                      )
                    ),
                  ),
                  InkWell(
                    splashColor: Colors.grey.shade200, // soft tap highlight
                    highlightColor: Colors.transparent,
                    onTap: () => Navigator.pop(context, "Bike"),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Text(
                            "🚴", 
                            style: TextStyle(fontSize: 20)
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Radfahrt",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ]
                      )
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Future<String?> showFrequencyDialog(BuildContext context, ) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20), // padding to screen edges
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.white,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Häufigkeit auswählen",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    splashColor: Colors.grey.shade200, // soft tap highlight
                    highlightColor: Colors.transparent,
                    onTap: () => Navigator.pop(context, "Einmalig"),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Text(
                            "🗓️",
                            style: TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Einmalig",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ]
                      )
                    ),
                  ),
                  InkWell(
                    splashColor: Colors.grey.shade200, // soft tap highlight
                    highlightColor: Colors.transparent,
                    onTap: () => Navigator.pop(context, "Wöchentlich"),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Text(
                            "🔁", 
                            style: TextStyle(fontSize: 20)
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Wöchentlich",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ]
                      )
                    ),
                  ),
                  InkWell(
                    splashColor: Colors.grey.shade200, // soft tap highlight
                    highlightColor: Colors.transparent,
                    onTap: () => Navigator.pop(context, "Monatlich"),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Text(
                            "🔁", 
                            style: TextStyle(fontSize: 20)
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Monatlich",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ]
                      )
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Future<int?> showDistanceDialog(BuildContext context) {
    int selectedKm = 5;
    int selectedMeters = 0;
    final kmController = FixedExtentScrollController(initialItem: selectedKm);
    final mController = FixedExtentScrollController(initialItem: selectedMeters);

    return showDialog<int>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Distanz auswählen",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // scroll wheel
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // KM picker
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              perspective: 0.003,
                              // useMagnifier: true,
                              // magnification: 1.15,
                              physics: FixedExtentScrollPhysics(),
                              controller: kmController,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedKm = index;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 1000,
                                builder: (context, index) {
                                  final bool isSelected = index == selectedKm;
                                  return Center(
                                    child: Text(
                                      "$index",
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: Colors.black.withOpacity(isSelected ? 1.0 : 0.35),
                                        // color: isSelected ? Colors.black : Colors.grey,
                                        // fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "km",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              )
                            )
                          )
                        ),
                        // meters picker
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              perspective: 0.003,
                              // useMagnifier: true,
                              // magnification: 1.15,
                              physics: FixedExtentScrollPhysics(),
                              controller: mController,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedMeters = index * 100;
                                });
                              },
                              childDelegate: ListWheelChildLoopingListDelegate(
                                children: List.generate(
                                  10,
                                  (index) => Center(
                                    child: Text(
                                      "${index * 100}",
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: index == selectedMeters ~/ 100
                                            ? Colors.black
                                            : Colors.grey,
                                        // fontWeight: index == selectedMeters ~/ 100
                                        //     ? FontWeight.w600 
                                        //     : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "m",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              )
                            )
                          )
                        ),
                      ]
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        int distance = selectedKm * 1000 + selectedMeters;
                        Navigator.pop(
                          context,
                          distance
                        );
                      },
                      child: const Text("Übernehmen"),
                    )
                  ]
                ),
              );
            }
          )
        );
      }
    );
  }

  Future<int?> showSpeedDialog(BuildContext context) {
    int selectedSpeed = 10; // default
    final controller = FixedExtentScrollController(initialItem: selectedSpeed);

    return showDialog<int>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Geschwindigkeit auswählen",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// 🔹 SINGLE WHEEL
                    SizedBox(
                      height: 120,
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 40,
                        perspective: 0.003,
                        physics: const FixedExtentScrollPhysics(),
                        controller: controller,
                        onSelectedItemChanged: (index) {
                          setState(() => selectedSpeed = index);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 51, // e.g. 0–30 km/h
                          builder: (context, index) {
                            final isSelected = index == selectedSpeed;

                            return Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 150),
                                style: TextStyle(
                                  fontSize: isSelected ? 30 : 22,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey.shade400,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("$index"),

                                    if (isSelected) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        "km/h",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, selectedSpeed);
                      },
                      child: const Text("Übernehmen"),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<int?> showPaceDialog(BuildContext context) {
    int selectedMinutes = 5;
    int selectedSeconds = 0;
    final minController = FixedExtentScrollController(initialItem: selectedMinutes);
    final sController = FixedExtentScrollController(initialItem: selectedSeconds);

    return showDialog<int>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Pace auswählen",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // scroll wheel
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // minute picker
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              perspective: 0.003,
                              // useMagnifier: true,
                              // magnification: 1.15,
                              physics: FixedExtentScrollPhysics(),
                              controller: minController,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedMinutes = index;
                                });
                              },
                              childDelegate: ListWheelChildLoopingListDelegate(
                                children: List.generate(
                                  60,
                                  (index) => Center(
                                    child: Text(
                                      "$index",
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: index == selectedMinutes
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "min",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              )
                            )
                          )
                        ),
                        // seconds picker
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              perspective: 0.003,
                              // useMagnifier: true,
                              // magnification: 1.15,
                              physics: FixedExtentScrollPhysics(),
                              controller: sController,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedSeconds = index;
                                });
                              },
                              childDelegate: ListWheelChildLoopingListDelegate(
                                children: List.generate(
                                  60,
                                  (index) => Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: index == selectedSeconds
                                            ? Colors.black
                                            : Colors.grey,
                                        // fontWeight: index == selectedMeters ~/ 100
                                        //     ? FontWeight.w600 
                                        //     : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "s",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              )
                            )
                          )
                        ),
                      ]
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        int pace = selectedMinutes*60 + selectedSeconds;
                        Navigator.pop(
                          context,
                          pace,
                        );
                      },
                      child: const Text("Übernehmen"),
                    )
                  ]
                ),
              );
            }
          )
        );
      }
    );
  }

  Future<DateTime?> showCalendarDialog(BuildContext context, {DateTime? initialDate}) {
    final today = DateTime.now();
    DateTime selectedDate = initialDate ?? today;
    DateTime displayedMonth = DateTime(selectedDate.year, selectedDate.month);

    return showDialog<DateTime>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: StatefulBuilder(
            builder: (context, setState) {
              // Calculate days in displayed month
              int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

              // First weekday of the month (1 = Monday, 7 = Sunday)
              int firstWeekday(DateTime month) => DateTime(month.year, month.month, 1).weekday;

              // Generate list of days including leading blanks for alignment
              List<DateTime?> generateDays(DateTime month) {
                int leadingBlanks = firstWeekday(month) - 1; // Make Monday = first column
                int totalDays = daysInMonth(month);
                return List<DateTime?>.generate(
                  leadingBlanks + totalDays,
                  (i) => i < leadingBlanks ? null : DateTime(month.year, month.month, i - leadingBlanks + 1),
                );
              }

              final days = generateDays(displayedMonth);

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month and year header with arrows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed: () {
                            setState(() {
                              displayedMonth = DateTime(displayedMonth.year, displayedMonth.month - 1);
                            });
                          },
                        ),
                        Text(
                          "${displayedMonth.year} / ${displayedMonth.month.toString().padLeft(2, '0')}",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          onPressed: () {
                            setState(() {
                              displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Weekday headers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const ["Mo","Tu","We","Th","Fr","Sa","Su"]
                          .map((d) => Expanded(
                            child: Center(child: Text(d, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
                          ))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    // Calendar grid
                    GridView.builder(
                      shrinkWrap: true,
                      itemCount: days.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final isSelected = day != null &&
                            day.year == selectedDate.year &&
                            day.month == selectedDate.month &&
                            day.day == selectedDate.day;
                        final isToday = day != null &&
                            day.year == today.year &&
                            day.month == today.month &&
                            day.day == today.day;

                        return GestureDetector(
                          onTap: day == null
                              ? null
                              : () {
                                  setState(() {
                                    selectedDate = day;
                                  });
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              day?.day.toString() ?? "",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                        ? Colors.black
                                        : Colors.grey,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, selectedDate),
                      child: const Text("Übernehmen"),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<DateTime?> showTimeDialog(BuildContext context) {
    int selectedHours = 12;
    int selectedMinutes = 0;
    final hController = FixedExtentScrollController(initialItem: selectedHours);
    final minController = FixedExtentScrollController(initialItem: selectedMinutes);

    return showDialog<DateTime>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Startzeit auswählen",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // scroll wheel
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // minute picker
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              perspective: 0.003,
                              // useMagnifier: true,
                              // magnification: 1.15,
                              physics: FixedExtentScrollPhysics(),
                              controller: hController,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedHours = index;
                                });
                              },
                              childDelegate: ListWheelChildLoopingListDelegate(
                                children: List.generate(
                                  24,
                                  (index) => Center(
                                    child: Text(
                                      "$index",
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: index == selectedHours
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "h",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              )
                            )
                          )
                        ),
                        // seconds picker
                        Expanded(
                          child: SizedBox(
                            height: 120,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              perspective: 0.003,
                              // useMagnifier: true,
                              // magnification: 1.15,
                              physics: FixedExtentScrollPhysics(),
                              controller: minController,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedMinutes = index;
                                });
                              },
                              childDelegate: ListWheelChildLoopingListDelegate(
                                children: List.generate(
                                  60,
                                  (index) => Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: index == selectedMinutes
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "min",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              )
                            )
                          )
                        ),
                      ]
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        DateTime selectedTime = DateTime(
                          0, 1, 1, 
                          selectedHours,
                          selectedMinutes
                        );
                        Navigator.pop(
                          context,
                          selectedTime,
                        );
                      },
                      child: const Text("Übernehmen"),
                    )
                  ]
                ),
              );
            }
          )
        );
      }
    );
  }
}