import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import '../services/auth_service.dart';
import '../Pages/home_Page.dart';

class CreateEventPage extends StatefulWidget {
  @override
  _CreateEventPageState createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final AuthService _authService = AuthService();
  
  String _title = '';
  String _description = '';
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay.fromDateTime(
    DateTime.now().add(Duration(hours: 1))
  );
  String _location = '';
  
  // Recurrence options
  bool _isRecurring = false;
  String _recurrencePattern = 'none'; // none, daily, weekly, monthly, yearly
  
  bool _isLoading = false;
  bool _isValidatingLocation = false;
  String _errorMessage = '';

  // Date and time selection methods
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
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
      setState(() {
        _startDate = picked;
        // If end date is before new start date, update end date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
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
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
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
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
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
      setState(() {
        _endTime = picked;
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

    setState(() {
      _isValidatingLocation = true;
    });

    try {
      final locations = await locationFromAddress(location);
      
      setState(() {
        _isValidatingLocation = false;
      });
      
      return locations.isNotEmpty;
    } catch (e) {
      setState(() {
        _isValidatingLocation = false;
      });
      return false;
    }
  }

  // Function to handle creating recurring events
  calendar.Event _prepareEventWithRecurrence(calendar.Event event) {
    if (!_isRecurring || _recurrencePattern == 'none') {
      return event;
    }
    
    List<String> recurrence = [];
    
    // Set up the recurrence rule based on selected pattern
    switch (_recurrencePattern) {
      case 'daily':
        recurrence.add('RRULE:FREQ=DAILY');
        break;
      case 'weekly':
        // Get the day of the week for the start date (SU, MO, TU, etc.)
        final days = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
        final dayOfWeek = days[_startDate.weekday % 7]; // Convert to RRULE day format
        recurrence.add('RRULE:FREQ=WEEKLY;BYDAY=$dayOfWeek');
        break;
      case 'monthly':
        // Repeat on the same day of the month
        recurrence.add('RRULE:FREQ=MONTHLY;BYMONTHDAY=${_startDate.day}');
        break;
      case 'yearly':
        // Repeat on the same day of the same month each year
        recurrence.add('RRULE:FREQ=YEARLY');
        break;
    }
    
    event.recurrence = recurrence;
    return event;
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    _formKey.currentState!.save();
    
    // Validate location before proceeding
    if (!(await _validateLocation(_location))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid location. Please enter a valid address.')),
      );
      return;
    }
    
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
      
      final startDateTime = _combineDateAndTime(_startDate, _startTime);
      final endDateTime = _combineDateAndTime(_endDate, _endTime);
      
      // Create event
      calendar.Event event = calendar.Event();
      event.summary = _title;
      event.description = _description;
      
      calendar.EventDateTime start = calendar.EventDateTime();
      start.dateTime = startDateTime.toUtc();
      start.timeZone = 'UTC';
      event.start = start;
      
      calendar.EventDateTime end = calendar.EventDateTime();
      end.dateTime = endDateTime.toUtc();
      end.timeZone = 'UTC';
      event.end = end;
      
      if (_location.isNotEmpty) {
        event.location = _location;
      }
      
      // Add recurrence if needed
      event = _prepareEventWithRecurrence(event);
      
      await calendarApi.events.insert(event, 'primary');
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isRecurring 
            ? 'Recurring Task created successfully!' 
            : 'Task created successfully!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      
      Navigator.pop(context, true); // Return true to indicate event was created
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error creating Task: $e';
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
          'Create Task/Event',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
                              'New Task/Event',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Fill in the details below',
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
                                  'Task Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextFormField(
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
                                      return 'Please enter a title';
                                    }
                                    return null;
                                  },
                                  onSaved: (value) {
                                    _title = value!;
                                  },
                                ),
                                SizedBox(height: 20),
                                TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Description',
                                    hintText: 'Enter event description (optional)',
                                    prefixIcon: Icon(Icons.description, color: Colors.blue.shade700),
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
                                  maxLines: 3,
                                  onSaved: (value) {
                                    _description = value ?? '';
                                  },
                                ),
                                
                                SizedBox(height: 32),
                                
                                // Date & Time Section
                                Text(
                                  'Date & Time',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _selectStartDate(context),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(12),
                                            color: Colors.grey.shade50,
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(Icons.calendar_today, color: Colors.blue.shade700),
                                              SizedBox(height: 8),
                                              Text(
                                                'Start Date',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                DateFormat('MMM d, yyyy').format(_startDate),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _selectStartTime(context),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(12),
                                            color: Colors.grey.shade50,
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(Icons.access_time, color: Colors.blue.shade700),
                                              SizedBox(height: 8),
                                              Text(
                                                'Start Time',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                _startTime.format(context),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _selectEndDate(context),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(12),
                                            color: Colors.grey.shade50,
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(Icons.calendar_today, color: Colors.blue.shade700),
                                              SizedBox(height: 8),
                                              Text(
                                                'End Date',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                DateFormat('MMM d, yyyy').format(_endDate),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _selectEndTime(context),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(12),
                                            color: Colors.grey.shade50,
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(Icons.access_time, color: Colors.blue.shade700),
                                              SizedBox(height: 8),
                                              Text(
                                                'End Time',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                _endTime.format(context),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 32),
                                
                                // Recurrence Section
                                Row(
                                  children: [
                                    Text(
                                      'Recurrence',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Switch(
                                      value: _isRecurring,
                                      onChanged: (value) {
                                        setState(() {
                                          _isRecurring = value;
                                          if (!value) {
                                            _recurrencePattern = 'none';
                                          } else if (_recurrencePattern == 'none') {
                                            _recurrencePattern = 'daily';
                                          }
                                        });
                                      },
                                      activeColor: Colors.blue.shade700,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                
                                // Recurrence options (only show when recurring is enabled)
                                if (_isRecurring)
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue.shade100),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Repeat Pattern',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        
                                        // Daily option
                                        RadioListTile<String>(
                                          title: Text('Every day'),
                                          value: 'daily',
                                          groupValue: _recurrencePattern,
                                          onChanged: (value) {
                                            setState(() {
                                              _recurrencePattern = value!;
                                            });
                                          },
                                          activeColor: Colors.blue.shade700,
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        ),
                                        
                                        // Weekly option
                                        RadioListTile<String>(
                                          title: Text('Weekly on ${DateFormat('EEEE').format(_startDate)}'),
                                          value: 'weekly',
                                          groupValue: _recurrencePattern,
                                          onChanged: (value) {
                                            setState(() {
                                              _recurrencePattern = value!;
                                            });
                                          },
                                          activeColor: Colors.blue.shade700,
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        ),
                                        
                                        // Monthly option
                                        RadioListTile<String>(
                                          title: Text('Monthly on day ${_startDate.day}'),
                                          value: 'monthly',
                                          groupValue: _recurrencePattern,
                                          onChanged: (value) {
                                            setState(() {
                                              _recurrencePattern = value!;
                                            });
                                          },
                                          activeColor: Colors.blue.shade700,
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        ),
                                        
                                        // Yearly option
                                        RadioListTile<String>(
                                          title: Text('Yearly on ${DateFormat('MMMM d').format(_startDate)}'),
                                          value: 'yearly',
                                          groupValue: _recurrencePattern,
                                          onChanged: (value) {
                                            setState(() {
                                              _recurrencePattern = value!;
                                            });
                                          },
                                          activeColor: Colors.blue.shade700,
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                SizedBox(height: 32),
                                
                                // Location Section
                                Text(
                                  'Location (Optional)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: _locationController,
                                  decoration: InputDecoration(
                                    labelText: 'Location',
                                    hintText: 'Enter event location',
                                    prefixIcon: Icon(Icons.location_on, color: Colors.blue.shade700),
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
                                    suffixIcon: _isValidatingLocation 
                                      ? Container(
                                          height: 20,
                                          width: 20,
                                          padding: EdgeInsets.all(8),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                                          ),
                                        )
                                      : IconButton(
                                          icon: Icon(Icons.search, color: Colors.blue.shade700),
                                          onPressed: () async {
                                            if (_locationController.text.isNotEmpty) {
                                              bool isValid = await _validateLocation(_locationController.text);
                                              if (!isValid) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Could not find this location'),
                                                    backgroundColor: Colors.red.shade600,
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Location validated'),
                                                    backgroundColor: Colors.green.shade600,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                  ),
                                  onSaved: (value) {
                                    _location = value ?? '';
                                  },
                                ),
                                
                                SizedBox(height: 32),
                                
                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56.0,
                                  child: ElevatedButton(
                                    onPressed: _createEvent,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      _isRecurring ? 'Create Recurring Task' : 'Create Task/Event',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}