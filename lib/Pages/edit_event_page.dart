import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:gotask/services/auth_service.dart';
import 'package:gotask/services/cloud_logger.dart';

class EditEventPage extends StatefulWidget {
  final calendar.Event event;
  
  const EditEventPage({Key? key, required this.event}) : super(key: key);

  @override
  _EditEventPageState createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final AuthService _authService = AuthService();
  
  late String _title;
  late String _description;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  late String _location;
  
  bool _isLoading = false;
  bool _isValidatingLocation = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    // Initialize form values from the event
    _title = widget.event.summary ?? '';
    _description = widget.event.description ?? '';
    
    final startDateTime = widget.event.start?.dateTime ?? DateTime.now();
    final endDateTime = widget.event.end?.dateTime ?? DateTime.now().add(Duration(hours: 1));
    
    _startDate = startDateTime;
    _startTime = TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute);
    
    _endDate = endDateTime;
    _endTime = TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute);
    
    _location = widget.event.location ?? '';
    _locationController.text = _location;
    
    CloudLogger().pageView('EditEventPage', {
      'eventId': widget.event.id,
      'eventTitle': widget.event.summary,
      'eventStartDate': startDateTime.toIso8601String(),
      'hasLocation': _location.isNotEmpty
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    CloudLogger().debug('EditEventPage disposed', {
      'eventType': 'PAGE_LIFECYCLE',
      'action': 'PAGE_DISPOSED',
      'eventId': widget.event.id
    });
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    CloudLogger().userAction('select_start_date_tapped', {
      'eventId': widget.event.id,
      'currentStartDate': DateFormat('yyyy-MM-dd').format(_startDate)
    });
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      CloudLogger().userAction('start_date_selected', {
        'eventId': widget.event.id,
        'previousDate': DateFormat('yyyy-MM-dd').format(_startDate),
        'selectedDate': DateFormat('yyyy-MM-dd').format(picked),
      });
      
      setState(() {
        _startDate = picked;
        // If end date is before new start date, update end date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
          
          CloudLogger().info('End date auto-adjusted to match start date', {
            'eventType': 'FORM_VALIDATION',
            'eventId': widget.event.id,
            'newEndDate': DateFormat('yyyy-MM-dd').format(_endDate)
          });
        }
      });
    } else {
      CloudLogger().userAction('start_date_selection_cancelled', {
        'eventId': widget.event.id
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    CloudLogger().userAction('select_start_time_tapped', {
      'eventId': widget.event.id,
      'currentStartTime': '${_startTime.hour}:${_startTime.minute}'
    });
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      CloudLogger().userAction('start_time_selected', {
        'eventId': widget.event.id,
        'previousTime': '${_startTime.hour}:${_startTime.minute}',
        'selectedTime': '${picked.hour}:${picked.minute}'
      });
      
      setState(() {
        _startTime = picked;
      });
    } else {
      CloudLogger().userAction('start_time_selection_cancelled', {
        'eventId': widget.event.id
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    CloudLogger().userAction('select_end_date_tapped', {
      'eventId': widget.event.id,
      'currentEndDate': DateFormat('yyyy-MM-dd').format(_endDate)
    });
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      CloudLogger().userAction('end_date_selected', {
        'eventId': widget.event.id,
        'previousDate': DateFormat('yyyy-MM-dd').format(_endDate),
        'selectedDate': DateFormat('yyyy-MM-dd').format(picked)
      });
      
      setState(() {
        _endDate = picked;
      });
    } else {
      CloudLogger().userAction('end_date_selection_cancelled', {
        'eventId': widget.event.id
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    CloudLogger().userAction('select_end_time_tapped', {
      'eventId': widget.event.id,
      'currentEndTime': '${_endTime.hour}:${_endTime.minute}'
    });
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      CloudLogger().userAction('end_time_selected', {
        'eventId': widget.event.id,
        'previousTime': '${_endTime.hour}:${_endTime.minute}',
        'selectedTime': '${picked.hour}:${picked.minute}'
      });
      
      setState(() {
        _endTime = picked;
      });
    } else {
      CloudLogger().userAction('end_time_selection_cancelled', {
        'eventId': widget.event.id
      });
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<bool> _validateLocation(String location) async {
    if (location.isEmpty) {
      return true; // Empty location is valid (optional field)
    }

    CloudLogger().info('Validating location for edit', {
      'eventType': 'LOCATION_VALIDATION',
      'action': 'VALIDATION_STARTED',
      'eventId': widget.event.id,
      'location': location
    });
    
    final stopwatch = Stopwatch()..start();
    setState(() {
      _isValidatingLocation = true;
    });

    try {
      final locations = await locationFromAddress(location);
      
      setState(() {
        _isValidatingLocation = false;
      });
      
      stopwatch.stop();
      final isValid = locations.isNotEmpty;
      
      CloudLogger().info('Location validation completed for edit', {
        'eventType': 'LOCATION_VALIDATION',
        'action': 'VALIDATION_COMPLETED',
        'eventId': widget.event.id,
        'location': location,
        'isValid': isValid,
        'durationMs': stopwatch.elapsedMilliseconds
      });
      
      return isValid;
    } catch (e) {
      setState(() {
        _isValidatingLocation = false;
      });
      
      stopwatch.stop();
      CloudLogger().error('Location validation failed for edit', {
        'eventType': 'LOCATION_VALIDATION',
        'action': 'VALIDATION_ERROR',
        'eventId': widget.event.id,
        'location': location,
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds
      });
      
      return false;
    }
  }

  Future<void> _updateEvent() async {
    CloudLogger().userAction('update_event_button_tapped', {
      'eventId': widget.event.id
    });
    
    if (!_formKey.currentState!.validate()) {
      CloudLogger().warn('Event update form validation failed', {
        'eventType': 'FORM_VALIDATION',
        'action': 'VALIDATION_FAILED',
        'eventId': widget.event.id
      });
      return;
    }
    
    _formKey.currentState!.save();
    
    // Validate location before proceeding
    if (_location.isNotEmpty) {
      final isValidLocation = await _validateLocation(_location);
      if (!isValidLocation) {
        CloudLogger().warn('Event update blocked due to invalid location', {
          'eventType': 'FORM_VALIDATION',
          'action': 'LOCATION_INVALID',
          'eventId': widget.event.id,
          'location': _location
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid location. Please enter a valid address.'),
            backgroundColor: Colors.red.shade600,
          ),
        );
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    final stopwatch = Stopwatch()..start();
    
    // Track what fields are being modified
    Map<String, dynamic> changedFields = {};
    if (_title != widget.event.summary) {
      changedFields['title'] = true;
    }
    if (_description != widget.event.description) {
      changedFields['description'] = true;
    }
    if (_location != widget.event.location) {
      changedFields['location'] = true;
    }
    
    final originalStartDateTime = widget.event.start?.dateTime;
    final newStartDateTime = _combineDateAndTime(_startDate, _startTime);
    if (originalStartDateTime != null && 
        (originalStartDateTime.day != newStartDateTime.day ||
         originalStartDateTime.month != newStartDateTime.month ||
         originalStartDateTime.year != newStartDateTime.year ||
         originalStartDateTime.hour != newStartDateTime.hour ||
         originalStartDateTime.minute != newStartDateTime.minute)) {
      changedFields['startDateTime'] = true;
    }
    
    final originalEndDateTime = widget.event.end?.dateTime;
    final newEndDateTime = _combineDateAndTime(_endDate, _endTime);
    if (originalEndDateTime != null &&
        (originalEndDateTime.day != newEndDateTime.day ||
         originalEndDateTime.month != newEndDateTime.month ||
         originalEndDateTime.year != newEndDateTime.year ||
         originalEndDateTime.hour != newEndDateTime.hour ||
         originalEndDateTime.minute != newEndDateTime.minute)) {
      changedFields['endDateTime'] = true;
    }
    
    CloudLogger().info('Updating calendar event', {
      'eventType': 'EVENT_UPDATE',
      'action': 'UPDATE_EVENT_STARTED',
      'eventId': widget.event.id,
      'title': _title,
      'description': _description.length,
      'startDateTime': newStartDateTime.toIso8601String(),
      'endDateTime': newEndDateTime.toIso8601String(),
      'hasLocation': _location.isNotEmpty,
      'changedFields': changedFields,
    });
    
    try {
      final calendarApi = await _authService.getCalendarApi();
      
      if (calendarApi == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get Calendar API client';
        });
        
        stopwatch.stop();
        CloudLogger().error('Failed to get Calendar API client for update', {
          'eventType': 'API_ERROR',
          'action': 'UPDATE_EVENT_FAILED',
          'reason': 'NULL_API_CLIENT',
          'eventId': widget.event.id,
          'durationMs': stopwatch.elapsedMilliseconds
        });
        return;
      }
      
      // Create updated event
      calendar.Event updatedEvent = calendar.Event();
      updatedEvent.id = widget.event.id;
      updatedEvent.summary = _title;
      updatedEvent.description = _description;
      
      calendar.EventDateTime start = calendar.EventDateTime();
      start.dateTime = newStartDateTime.toUtc();
      start.timeZone = 'UTC';
      updatedEvent.start = start;
      
      calendar.EventDateTime end = calendar.EventDateTime();
      end.dateTime = newEndDateTime.toUtc();
      end.timeZone = 'UTC';
      updatedEvent.end = end;
      
      if (_location.isNotEmpty) {
        updatedEvent.location = _location;
      }
      
      // Update the event
      final apiStopwatch = Stopwatch()..start();
      final updatedEventResult = await calendarApi.events.update(updatedEvent, 'primary', widget.event.id!);
      apiStopwatch.stop();
      
      setState(() {
        _isLoading = false;
      });
      
      stopwatch.stop();
      CloudLogger().info('Calendar event updated successfully', {
        'eventType': 'EVENT_UPDATE',
        'action': 'UPDATE_EVENT_COMPLETED',
        'eventId': widget.event.id,
        'eventTitle': updatedEvent.summary,
        'changedFieldCount': changedFields.length,
        'apiCallDurationMs': apiStopwatch.elapsedMilliseconds,
        'totalDurationMs': stopwatch.elapsedMilliseconds
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event updated successfully!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      
      Navigator.pop(context, true); // Return true to indicate event was updated
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error updating event: $e';
      });
      
      stopwatch.stop();
      CloudLogger().error('Error updating calendar event', {
        'eventType': 'API_ERROR',
        'action': 'UPDATE_EVENT_ERROR',
        'eventId': widget.event.id,
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
        title: Text(
          'Edit Task/Event',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            CloudLogger().userAction('edit_event_cancelled', {
              'eventId': widget.event.id,
              'eventTitle': widget.event.summary
            });
            Navigator.pop(context, false);
          },
        ),
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
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Task/Event',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Update Task/Event details',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Form Card
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_errorMessage.isNotEmpty)
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    margin: EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage,
                                            style: TextStyle(color: Colors.red.shade700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                // Title Section
                                Text(
                                  'Task/Event Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  initialValue: _title,
                                  decoration: InputDecoration(
                                    labelText: 'Title',
                                    hintText: 'Enter event title',
                                    prefixIcon: Icon(Icons.title, color: Colors.blue.shade700),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      CloudLogger().warn('Title validation failed in edit', {
                                        'eventType': 'FORM_VALIDATION',
                                        'field': 'title',
                                        'reason': 'EMPTY_FIELD',
                                        'eventId': widget.event.id
                                      });
                                      return 'Please enter a title';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) {
                                    _title = value!;
                                    if (_title != widget.event.summary) {
                                      CloudLogger().debug('Title changed in edit', {
                                        'eventType': 'FORM_INPUT',
                                        'field': 'title',
                                        'eventId': widget.event.id,
                                        'originalLength': widget.event.summary?.length ?? 0,
                                        'newLength': _title.length,
                                        'changed': true
                                      });
                                    }
                                  },
                                ),
                                SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // App info
                      Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          'GoTask v1.0.0',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}