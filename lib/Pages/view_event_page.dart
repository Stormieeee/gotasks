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
    final duration = endDateTime.difference(startDateTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    String durationText = '';
    if (hours > 0) {
      durationText += '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    if (minutes > 0) {
      durationText += durationText.isNotEmpty ? ' ' : '';
      durationText += '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom app bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade800,
                    Colors.blue.shade600,
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                title: Text(
                  'Event Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Padding(
                  padding: EdgeInsets.only(top: 30, left: 16, right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit),
                tooltip: 'Edit Event',
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditEventPage(event: widget.event),
                    ),
                  );
                  
                  if (result == true) {
                    widget.onEventUpdated();
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event summary/title
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event.summary ?? 'Untitled Event',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Event details card
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            // Date row
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            Divider(height: 30),
                            
                            // Time row
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.access_time,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Time',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '$formattedStartTime - $formattedEndTime',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (durationText.isNotEmpty) ...[
                                        SizedBox(height: 2),
                                        Text(
                                          '($durationText)',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            if (widget.event.location != null && widget.event.location!.isNotEmpty) ...[
                              Divider(height: 30),
                              
                              // Location row
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.blue.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Location',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          widget.event.location!,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Description section
                    if (widget.event.description != null && widget.event.description!.isNotEmpty) ...[
                      SizedBox(height: 24),
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            widget.event.description!,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    // Map section
                    SizedBox(height: 24),
                    Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: _isLoadingMap
                                ? Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                                    ),
                                  )
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
                                              backgroundColor: Colors.blue.shade700,
                                              foregroundColor: Colors.white,
                                              onPressed: _navigateToLocation,
                                              child: Icon(Icons.directions),
                                              tooltip: 'Navigate',
                                            ),
                                          ),
                                        ],
                                      )
                                    : Container(
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.location_off,
                                                size: 60,
                                                color: Colors.grey.shade500,
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                _locationError ?? 'No location specified',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                          ),
                          if (_locationCoordinates != null)
                            InkWell(
                              onTap: _navigateToLocation,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.directions, color: Colors.blue.shade700),
                                    SizedBox(width: 8),
                                    Text(
                                      'Navigate to location',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
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
                    
                    // Delete button
                    SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.delete_outline),
                        label: Text(
                          'Delete Event',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Delete Event'),
                              content: Text('Are you sure you want to delete "${widget.event.summary}"?'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text('DELETE'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
                                ),
                              ],
                            ),
                          ) ?? false;

                          if (shouldDelete) {
                            widget.onEventDeleted();
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                    
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}