import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/leave_request_model.dart';
import '../../services/firestore_service.dart';
import '../../services/pdf_service.dart'; // ✅ Added
import '../../utils/admin_helpers.dart';

class DepartmentCalendarScreen extends StatefulWidget {
  final String? adminDepartment; // Legacy support
  const DepartmentCalendarScreen({super.key, this.adminDepartment});

  @override
  State<DepartmentCalendarScreen> createState() => _DepartmentCalendarScreenState();
}

class _DepartmentCalendarScreenState extends State<DepartmentCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final FirestoreService _firestoreService = FirestoreService();
  final PdfService _pdfService = PdfService(); // ✅ Added
  
  // Cache requests for the month
  Map<DateTime, List<LeaveRequestModel>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  /// Groups leaves by date for the calendar
  Map<DateTime, List<LeaveRequestModel>> _groupLeaves(List<LeaveRequestModel> leaves) {
    Map<DateTime, List<LeaveRequestModel>> data = {};
    for (var leave in leaves) {
      if (leave.status == 'Rejected') continue; // Don't show rejected

      // Simple single day handling for now (expand for multi-day if needed)
      // For multi-day, we'd need to loop from start to end
      DateTime start = leave.fromDate;
      DateTime end = leave.toDate;
      
      int days = end.difference(start).inDays + 1;
      for (int i = 0; i < days; i++) {
        DateTime day = DateTime(start.year, start.month, start.day + i);
        // Normalize to UTC/ignoring time part effectively for key matching
        DateTime key = DateTime.utc(day.year, day.month, day.day);
        
        if (data[key] == null) data[key] = [];
        data[key]!.add(leave);
      }
    }
    return data;
  }

  List<LeaveRequestModel> _getEventsForDay(DateTime day) {
    DateTime key = DateTime.utc(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  String _selectedFilter = "All";

  List<String> _getUniqueLeaveTypes(List<LeaveRequestModel> events) {
    final types = events.map((e) => e.leaveType).toSet().toList();
    return ["All", ...types];
  }

  // Selection State
  final Set<String> _selectedRequestIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedRequestIds.contains(id)) {
        _selectedRequestIds.remove(id);
      } else {
        _selectedRequestIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<LeaveRequestModel> currentList) {
    setState(() {
      if (_selectedRequestIds.length == currentList.length && currentList.isNotEmpty) {
        _selectedRequestIds.clear();
      } else {
        _selectedRequestIds.clear();
        _selectedRequestIds.addAll(currentList.map((e) => e.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Department Calendar", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        // Removed global action button to move it to the panel
      ),
      body: StreamBuilder<List<LeaveRequestModel>>(
        stream: _firestoreService.getLeaveRequestsStream(department: widget.adminDepartment ?? 'CSE'), // ✅ Dept-scoped
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _events = _groupLeaves(snapshot.data!);
          } else if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          final allEventsForDay = _selectedDay != null ? _getEventsForDay(_selectedDay!) : <LeaveRequestModel>[];
          
          // Filter Logic
          final selectedEvents = _selectedFilter == "All" 
              ? allEventsForDay 
              : allEventsForDay.where((e) => e.leaveType == _selectedFilter).toList();
          
          // Get available types for the dropdown based on ALL events for the day (so user knows what's possible)
          final availableTypes = _getUniqueLeaveTypes(allEventsForDay);
          
          // Reset filter if selected type no longer exists for this day (optional, but good UX)
          // Actually, keeping it might be better if user switches days. 
          // But purely for safety:
          if (!availableTypes.contains(_selectedFilter) && _selectedFilter != "All") {
             // _selectedFilter = "All"; // Decide if we want auto-reset. Let's keep it sticky for now.
          }

          // Check if all displayed events are selected
          final areAllSelected = selectedEvents.isNotEmpty && 
                                 selectedEvents.every((e) => _selectedRequestIds.contains(e.id));

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool isMobile = constraints.maxWidth < 900;
              
              Widget calendarPanel = Container(
                margin: EdgeInsets.all(isMobile ? 12 : 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AdminHelpers.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AdminHelpers.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TableCalendar<LeaveRequestModel>(
                      firstDay: DateTime.utc(2023, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: _getEventsForDay,
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.sunday, // Standardized
                      rowHeight: 52,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AdminHelpers.primaryColor),
                        leftChevronIcon: Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white70 : AdminHelpers.primaryColor),
                        rightChevronIcon: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white70 : AdminHelpers.primaryColor),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                        weekendStyle: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                          _selectedFilter = "All"; // Reset filter 
                          _selectedRequestIds.clear(); // Reset selection
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      calendarBuilders: CalendarBuilders(
                        // Today
                        todayBuilder: (context, date, _) {
                          return Container(
                            margin: const EdgeInsets.all(6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AdminHelpers.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AdminHelpers.primaryColor.withOpacity(0.2)),
                            ),
                            child: Text("${date.day}", style: TextStyle(color: isDark ? Colors.white : AdminHelpers.primaryColor, fontWeight: FontWeight.bold)),
                          );
                        },
                        // Selected
                        selectedBuilder: (context, date, _) {
                          return Container(
                            margin: const EdgeInsets.all(6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AdminHelpers.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: AdminHelpers.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Text("${date.day}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          );
                        },
                        // Markers
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: events.take(3).map((e) {
                               return Container(
                                 margin: const EdgeInsets.symmetric(horizontal: 1),
                                 width: 5, height: 5,
                                 decoration: const BoxDecoration(color: AdminHelpers.secondaryColor, shape: BoxShape.circle),
                               );
                            }).toList(),
                          );
                        },
                        // Default
                        defaultBuilder: (context, date, _) {
                          return Container(
                            alignment: Alignment.center,
                            child: Text("${date.day}", style: TextStyle(color: isDark ? Colors.white : AdminHelpers.textMain, fontWeight: FontWeight.w500)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendItem(AdminHelpers.secondaryColor, "Present / Leaves", isDark),
                        const SizedBox(width: 16),
                        _legendItem(AdminHelpers.primaryColor, "Selected", isDark),
                      ],
                    )
                  ],
                ),
              );

              Widget detailsPanel = Container(
                margin: EdgeInsets.fromLTRB(isMobile ? 12 : 0, isMobile ? 12 : 24, isMobile ? 12 : 24, 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AdminHelpers.darkSurface : Colors.white, 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AdminHelpers.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Text(
                      _selectedDay != null 
                      ? DateFormat('MMMM dd, yyyy').format(_selectedDay!)
                      : "Select a Date",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AdminHelpers.textMain),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${selectedEvents.length} Leaves • ${_selectedFilter == 'All' ? 'All Types' : AdminHelpers.getLeaveName(_selectedFilter)}",
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Row(
                       children: [
                         Expanded(
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12),
                             decoration: BoxDecoration(
                               color: theme.cardColor,
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: theme.dividerColor),
                             ),
                             child: DropdownButtonHideUnderline(
                               child: DropdownButton<String>(
                                 value: availableTypes.contains(_selectedFilter) ? _selectedFilter : "All",
                                 isExpanded: true,
                                 icon: const Icon(Icons.filter_list_rounded, size: 20),
                                 items: availableTypes.map((type) {
                                   return DropdownMenuItem(
                                     value: type,
                                     child: Text(
                                       type == "All" ? "All Types" : AdminHelpers.getLeaveName(type),
                                       style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                     ),
                                   );
                                 }).toList(),
                                 onChanged: (val) {
                                   if (val != null) setState(() {
                                     _selectedFilter = val;
                                     _selectedRequestIds.clear(); // Reset selection on filter change
                                   });
                                 },
                               ),
                             ),
                           ),
                         ),
                         const SizedBox(width: 12),
                         InkWell(
                           onTap: _selectedRequestIds.isEmpty ? null : () async {
                              final batch = selectedEvents.where((e) => _selectedRequestIds.contains(e.id)).toList();
                              await _pdfService.generateBatchApplications(batch);
                           },
                           borderRadius: BorderRadius.circular(12),
                           child: Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: _selectedRequestIds.isEmpty ? Colors.grey[300] : AdminHelpers.primaryColor,
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: const Icon(Icons.download_rounded, color: Colors.white),
                           ),
                         )
                       ],
                    ),
                    if (selectedEvents.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: InkWell(
                          onTap: () => _toggleSelectAll(selectedEvents),
                          child: Row(
                            children: [
                              Checkbox(
                                value: areAllSelected,
                                onChanged: (val) => _toggleSelectAll(selectedEvents),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              const Text("Select All", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const Spacer(),
                              if (_selectedRequestIds.isNotEmpty)
                                Text("${_selectedRequestIds.length} Selected", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminHelpers.primaryColor, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (isMobile) 
                       ...selectedEvents.map((req) => _buildRequestItem(req, theme, _selectedRequestIds.contains(req.id))).toList()
                    else
                      Expanded(
                        child: selectedEvents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.filter_list_off_rounded, size: 48, color: theme.disabledColor.withOpacity(0.3)),
                                const SizedBox(height: 12),
                                Text(
                                  allEventsForDay.isEmpty ? "No leaves on this day" : "No leaves match filter", 
                                  style: TextStyle(color: theme.disabledColor)
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: selectedEvents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _buildRequestItem(selectedEvents[index], theme, _selectedRequestIds.contains(selectedEvents[index].id)),
                          ),
                      ),
                  ],
                ),
              );

              if (isMobile) {
                return ListView(
                  children: [
                    calendarPanel,
                    detailsPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: calendarPanel),
                  Expanded(flex: 3, child: detailsPanel),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestItem(LeaveRequestModel req, ThemeData theme, bool isSelected) {
    return InkWell(
      onTap: () => _toggleSelection(req.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AdminHelpers.primaryColor.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AdminHelpers.primaryColor.withOpacity(0.2) : theme.dividerColor.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(req.id),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Minor aesthetic tweak
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    "${AdminHelpers.getLeaveName(req.leaveType)} • ${req.numberOfDays} Days",
                    style: TextStyle(fontSize: 12, color: theme.disabledColor),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AdminHelpers.getStatusColor(req.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                req.status,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminHelpers.getStatusColor(req.status)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : AdminHelpers.textMain)),
      ],
    );
  }
}
