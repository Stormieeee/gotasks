import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:gotask/Pages/calendar_page.dart';
import 'package:gotask/Pages/create_event_page.dart';
import 'package:gotask/Pages/edit_event_page.dart';
import 'package:gotask/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:gotask/Pages/view_event_page.dart';
import 'package:gotask/Pages/profile_page.dart';

class ListPage extends StatefulWidget {
  const ListPage({Key? key}) : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<ListPage> {
  final AuthService _authService = AuthService();
  List<calendar.Event> _events = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchCalendarEvents();
  }

  Future<void> _fetchCalendarEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final calendarApi = await _authService.getCalendarApi();
      
      if (calendarApi == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get Calendar API client';
        });
        return;
      }

      // Get events from primary calendar for next 30 days
      final now = DateTime.now();
      final days = now.add(Duration(days: 30));
      
      final events = await calendarApi.events.list(
        'primary',
        timeMin: now.toUtc(),
        timeMax: days.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      setState(() {
        _events = events.items ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching calendar events: $e';
      });
    }
  }

  Future<void> _deleteEvent(calendar.Event event) async {
    // Show confirmation dialog before deleting
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Task/Event'),
        content: Text('Are you sure you want to clear this task "${event.summary}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('CLEAR'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldDelete) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final calendarApi = await _authService.getCalendarApi();
      
      if (calendarApi == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get Calendar API client';
        });
        return;
      }

      // Delete the event
      await calendarApi.events.delete('primary', event.id!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task cleared successfully')),
      );
      
      // Refresh the calendar
      _fetchCalendarEvents();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error clearing event: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing event')),
      );
    }
  }

  Future<void> _viewEventDetails(calendar.Event event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(
          event: event,
          onEventDeleted: () => _deleteEvent(event),
          onEventUpdated: _fetchCalendarEvents,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
        title: Text(
          'GoTask',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchCalendarEvents,
            tooltip: 'Refresh Tasks/Events',
          ),
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(user: _authService.currentUser!),
                ),
              );
  },
  tooltip: 'User Profile',
),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Header section
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Tasks/Events',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Next 30 days',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Main content
            Padding(
              padding: EdgeInsets.only(top: 80),
              child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Colors.red.shade300,
                            ),
                            SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red.shade300),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _fetchCalendarEvents,
                              child: Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _events.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 80,
                                  color: Colors.blue.shade200,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No events scheduled',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap the + button to create a new Task/Event',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            child: Container(
                              color: Colors.white,
                              child: ListView.builder(
                                padding: EdgeInsets.only(top: 16, bottom: 80),
                                itemCount: _events.length,
                                itemBuilder: (context, index) {
                                  final event = _events[index];
                                  final start = event.start?.dateTime ?? DateTime.now();
                                  final end = event.end?.dateTime ?? DateTime.now();
                                  
                                  // Show date header for each new date
                                  bool showHeader = index == 0 || 
                                    !isSameDay(start, _events[index - 1].start?.dateTime);
                                  
                                  final formattedStartTime = DateFormat('h:mm a').format(start);
                                  final formattedEndTime = DateFormat('h:mm a').format(end);
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (showHeader)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            left: 24, 
                                            right: 24, 
                                            top: index == 0 ? 8 : 24, 
                                            bottom: 12
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                DateFormat('EEEE').format(start),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('MMMM d, yyyy').format(start),
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Card(
                                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: InkWell(
                                          onTap: () => _viewEventDetails(event),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Column(
                                              children: [
                                                ListTile(
                                                  leading: Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.event,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    event.summary ?? 'Untitled Task',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.access_time,
                                                            size: 14,
                                                            color: Colors.grey.shade600,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            '$formattedStartTime - $formattedEndTime',
                                                            style: TextStyle(
                                                              color: Colors.grey.shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (event.location != null && event.location!.isNotEmpty)
                                                        Padding(
                                                          padding: EdgeInsets.only(top: 4),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.location_on,
                                                                size: 14,
                                                                color: Colors.grey.shade600,
                                                              ),
                                                              SizedBox(width: 4),
                                                              Expanded(
                                                                child: Text(
                                                                  event.location!,
                                                                  style: TextStyle(
                                                                    color: Colors.grey.shade700,
                                                                    fontSize: 12,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  isThreeLine: true,
                                                  trailing: Icon(
                                                    Icons.chevron_right,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    TextButton.icon(
                                                      icon: Icon(
                                                        Icons.edit,
                                                        size: 18,
                                                      ),
                                                      label: Text('Edit'),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors.blue.shade700,
                                                      ),
                                                      onPressed: () async {
                                                        final result = await Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => EditEventPage(event: event),
                                                          ),
                                                        );
                                                        
                                                        if (result == true) {
                                                          _fetchCalendarEvents();
                                                        }
                                                      },
                                                    ),
                                                    TextButton.icon(
                                                      icon: Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                      ),
                                                      label: Text('Clear'),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors.red,
                                                      ),
                                                      onPressed: () => _deleteEvent(event),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
            ),
            
            // Calendar view button
            Positioned(
              left: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: "switchToCalendar",
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                elevation: 4,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CalendarPage(),
                    ),
                  );
                },
                child: Icon(Icons.calendar_month),
                tooltip: 'Switch to Calendar View',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "addEvent",
        backgroundColor: Colors.blue.shade700,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEventPage(),
            ),
          );
          
          if (result == true) {
            _fetchCalendarEvents();
          }
        },
        child: Icon(Icons.add),
        tooltip: 'Add Task',
      ),
    );
  }
  
  // Helper function to check if two dates are the same day
  bool isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
}