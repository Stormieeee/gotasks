import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_event_page.dart';

class EventDetailsPage extends StatefulWidget {
  final calendar.Event event;
  final Function onEventDeleted;
  final Function onEventUpdated;

  const EventDetailsPage({
    Key? key,
    required this.event,
    required this.onEventDeleted,
    required this.onEventUpdated,
  }) : super(key: key);

  @override
  _EventDetailsPageState createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  bool _isLoadingMap = true;
  LatLng? _locationCoordinates;
  String? _locationError;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _getLocationCoordinates();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getLocationCoordinates() async {
    if (widget.event.location == null || widget.event.location!.isEmpty) {
      setState(() {
        _isLoadingMap = false;
        _locationError = "No location specified";
      });
      return;
    }

    try {
      final locations = await locationFromAddress(widget.event.location!);
      if (locations.isNotEmpty) {
        setState(() {
          _locationCoordinates = LatLng(locations.first.latitude, locations.first.longitude);
          _isLoadingMap = false;
        });
      } else {
        setState(() {
          _isLoadingMap = false;
          _locationError = "Could not find location";
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMap = false;
        _locationError = "Error finding location";
      });
    }
  }

  Future<void> _navigateToLocation() async {
    if (widget.event.location == null || widget.event.location!.isEmpty) {
      return;
    }

    // Google Maps URL for navigation
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.event.location!)}',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open maps for navigation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final startDateTime = widget.event.start?.dateTime ?? DateTime.now();
    final endDateTime = widget.event.end?.dateTime ?? DateTime.now();
    
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(startDateTime);
    final formattedStartTime = DateFormat('h:mm a').format(startDateTime);
    final formattedEndTime = DateFormat('h:mm a').format(endDateTime);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditEventPage(event: widget.event),
                ),
              );
              
              if (result == true) {
                widget.onEventUpdated();
                Navigator.pop(context); // Return to calendar after update
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event details card
              Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.summary ?? 'Untitled Event',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            '$formattedStartTime - $formattedEndTime',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      if (widget.event.location != null && widget.event.location!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.event.location!,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Location map card - REVISED SECTION
              SizedBox(height: 16),
              Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      height: 200,
                      width: double.infinity,
                      child: _isLoadingMap
                          ? Center(child: CircularProgressIndicator())
                          : _locationCoordinates != null
                              ? Stack(
                                  children: [
                                    GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: _locationCoordinates!,
                                        zoom: 14,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId: MarkerId('eventLocation'),
                                          position: _locationCoordinates!,
                                          infoWindow: InfoWindow(
                                            title: widget.event.summary,
                                            snippet: widget.event.location,
                                          ),
                                        ),
                                      },
                                      myLocationEnabled: false,
                                      zoomControlsEnabled: true,
                                      mapToolbarEnabled: false,
                                      onMapCreated: (GoogleMapController controller) {
                                        _mapController = controller;
                                        // This might help with the orange screen issue
                                        Future.delayed(Duration(milliseconds: 200), () {
                                          controller.animateCamera(
                                            CameraUpdate.newLatLngZoom(_locationCoordinates!, 14),
                                          );
                                        });
                                      },
                                    ),
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: FloatingActionButton.small(
                                        onPressed: _navigateToLocation,
                                        child: Icon(Icons.directions),
                                        tooltip: 'Navigate',
                                      ),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_off,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        _locationError ?? 'No location specified',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                    if (_locationCoordinates != null)
                      InkWell(
                        onTap: _navigateToLocation,
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Navigate to location',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Description card
              if (widget.event.description != null && widget.event.description!.isNotEmpty) ...[
                SizedBox(height: 16),
                Card(
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          widget.event.description!,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  icon: Icon(Icons.delete),
                  label: Text('Delete Event'),
                  onPressed: () async {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Delete Event'),
                        content: Text('Are you sure you want to delete "${widget.event.summary}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('DELETE'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                        ],
                      ),
                    ) ?? false;

                    if (shouldDelete) {
                      widget.onEventDeleted();
                      Navigator.pop(context); // Return to calendar after deletion
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}