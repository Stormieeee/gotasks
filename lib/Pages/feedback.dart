import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'package:gotask/services/cloud_logger.dart';

class FeedbackPage extends StatefulWidget {
  final User user;
  
  const FeedbackPage({Key? key, required this.user}) : super(key: key);

  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _feedbackType = 'Suggestion';
  bool _isLoading = false;
  bool _isSent = false;
  String _errorMessage = '';
  String _testResult = '';
  bool _isTestingFirestore = false;
  
  // Feedback type options
  final List<String> _feedbackTypes = [
    'Suggestion',
    'Bug Report',
    'Feature Request',
    'General Feedback',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    CloudLogger().pageView('FeedbackPage', {
      'userId': widget.user.uid,
      'userEmail': widget.user.email,
      'source': 'initState'
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    CloudLogger().debug('FeedbackPage disposed', {
      'eventType': 'PAGE_LIFECYCLE',
      'action': 'PAGE_DISPOSED',
      'userId': widget.user.uid
    });
    super.dispose();
  }

  // Log a message and update test results
  void _log(String message) {
    developer.log(message, name: 'FIRESTORE_TEST');
    CloudLogger().debug('Firestore test log', {
      'eventType': 'FIRESTORE_TEST',
      'message': message,
      'userId': widget.user.uid
    });
    setState(() {
      _testResult = '$message\n$_testResult';
    });
  }

  // Test Firestore connection
  Future<void> _testFirestoreConnection() async {
    CloudLogger().userAction('firestore_test_started', {
      'source': 'FeedbackPage',
      'userId': widget.user.uid
    });
    
    setState(() {
      _isTestingFirestore = true;
      _testResult = '';
    });
    
    final stopwatch = Stopwatch()..start();
    
    try {
      _log('Testing Firestore connection...');
      _log('Firebase initialized: ${FirebaseAuth.instance.app != null ? 'YES' : 'NO'}');
      
      // Get the Firestore instance
      final firestore = FirebaseFirestore.instance;
      _log('Firestore instance created');
      
      // Try to write a test document
      _log('Attempting to write test document to "feedback" collection...');
      
      DocumentReference docRef = await firestore.collection('feedback').add({
        'testUser': widget.user.uid,
        'testEmail': widget.user.email,
        'testMessage': 'This is a test from the app',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _log('SUCCESS! Test document written with ID: ${docRef.id}');
      _log('Firestore connection is working correctly!');
      
      stopwatch.stop();
      CloudLogger().info('Firestore test completed successfully', {
        'eventType': 'FIRESTORE_TEST',
        'action': 'TEST_COMPLETED',
        'success': true,
        'documentId': docRef.id,
        'durationMs': stopwatch.elapsedMilliseconds,
        'userId': widget.user.uid
      });
      
    } catch (e) {
      stopwatch.stop();
      _log('ERROR: $e');
      
      CloudLogger().error('Firestore test failed', {
        'eventType': 'FIRESTORE_TEST',
        'action': 'TEST_ERROR',
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'userId': widget.user.uid
      });
    } finally {
      setState(() {
        _isTestingFirestore = false;
      });
    }
  }

  Future<void> _submitFeedback() async {
    CloudLogger().userAction('submit_feedback_button_tapped', {
      'feedbackType': _feedbackType,
      'subjectLength': _subjectController.text.length,
      'messageLength': _messageController.text.length,
      'userId': widget.user.uid
    });
    
    if (!_formKey.currentState!.validate()) {
      CloudLogger().warn('Feedback validation failed', {
        'eventType': 'FORM_VALIDATION',
        'action': 'VALIDATION_FAILED',
        'userId': widget.user.uid,
        'subjectLength': _subjectController.text.length,
        'messageLength': _messageController.text.length,
        'feedbackType': _feedbackType
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    final stopwatch = Stopwatch()..start();
    CloudLogger().info('Submitting feedback', {
      'eventType': 'FEEDBACK_SUBMISSION',
      'action': 'SUBMISSION_STARTED',
      'feedbackType': _feedbackType,
      'subjectLength': _subjectController.text.length,
      'messageLength': _messageController.text.length,
      'userId': widget.user.uid
    });
    
    try {
      // Get form data
      final String subject = _subjectController.text.trim();
      final String message = _messageController.text.trim();
      
      // Save to Firestore
      final DocumentReference docRef = await FirebaseFirestore.instance.collection('feedback').add({
        'userId': widget.user.uid,
        'userEmail': widget.user.email,
        'userName': widget.user.displayName,
        'feedbackType': _feedbackType,
        'subject': subject,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'new',
      });
      
      setState(() {
        _isLoading = false;
        _isSent = true;
      });
      
      stopwatch.stop();
      CloudLogger().info('Feedback submitted successfully', {
        'eventType': 'FEEDBACK_SUBMISSION',
        'action': 'SUBMISSION_COMPLETED',
        'feedbackType': _feedbackType,
        'documentId': docRef.id,
        'durationMs': stopwatch.elapsedMilliseconds,
        'userId': widget.user.uid
      });
      
      // Reset form
      _subjectController.clear();
      _messageController.clear();
      setState(() {
        _feedbackType = 'Suggestion';
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error submitting feedback: $e';
      });
      
      stopwatch.stop();
      CloudLogger().error('Error submitting feedback', {
        'eventType': 'FEEDBACK_SUBMISSION',
        'action': 'SUBMISSION_ERROR',
        'feedbackType': _feedbackType,
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds,
        'userId': widget.user.uid
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit feedback. Please try again.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
        title: Text(
          'Send Feedback',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            CloudLogger().userAction('feedback_back_button_pressed', {
              'wasSent': _isSent,
              'userId': widget.user.uid
            });
            Navigator.of(context).pop();
          },
        ),
        actions: [
          // Debug test button in the app bar
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: () {
              CloudLogger().userAction('firestore_test_button_pressed', {
                'source': 'AppBar',
                'userId': widget.user.uid
              });
              
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Firestore Test'),
                  content: Container(
                    width: double.maxFinite,
                    height: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: _isTestingFirestore ? null : _testFirestoreConnection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                          ),
                          child: _isTestingFirestore
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Test Firestore Connection'),
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _testResult.isEmpty ? 'No test results yet' : _testResult,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        CloudLogger().userAction('firestore_test_dialog_closed', {
                          'userId': widget.user.uid
                        });
                        Navigator.pop(context);
                      },
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
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
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : _isSent
                  ? _buildSuccessView()
                  : _buildFeedbackForm(),
        ),
      ),
    );
  }
  
  Widget _buildSuccessView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.green.shade100,
                      child: Icon(
                        Icons.check,
                        size: 80,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  Text(
                    'Thank You!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your feedback has been submitted successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'We appreciate your input and will review it soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Spacer(flex: 1),
                  SizedBox(
                    width: double.infinity,
                    height: 56.0,
                    child: ElevatedButton(
                      onPressed: () {
                        CloudLogger().userAction('send_another_feedback_button_pressed', {
                          'userId': widget.user.uid
                        });
                        
                        setState(() {
                          _isSent = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Send Another Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56.0,
                    child: OutlinedButton(
                      onPressed: () {
                        CloudLogger().userAction('return_to_profile_button_pressed', {
                          'fromSuccessScreen': true,
                          'userId': widget.user.uid
                        });
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Return to Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                  Text(
                    'GoTask v1.0.0',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We Value Your Feedback',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Help us improve GoTask',
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
                    
                    // Feedback Type
                    Text(
                      'Feedback Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _feedbackType,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade700),
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                          items: _feedbackTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              CloudLogger().userAction('feedback_type_changed', {
                                'previousType': _feedbackType,
                                'newType': newValue,
                                'userId': widget.user.uid
                              });
                              
                              setState(() {
                                _feedbackType = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Subject
                    Text(
                      'Subject',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        hintText: 'Enter a subject',
                        prefixIcon: Icon(Icons.subject, color: Colors.blue.shade700),
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
                        if (value == null || value.trim().isEmpty) {
                          CloudLogger().warn('Subject validation failed', {
                            'eventType': 'FORM_VALIDATION',
                            'field': 'subject',
                            'reason': 'EMPTY_FIELD',
                            'userId': widget.user.uid
                          });
                          return 'Please enter a subject';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Log only when significant changes occur to reduce noise
                        if (value.length == 10 || value.length % 20 == 0) {
                          CloudLogger().debug('Subject input updated', {
                            'eventType': 'FORM_INPUT',
                            'field': 'subject',
                            'length': value.length,
                            'userId': widget.user.uid
                          });
                        }
                      },
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Message
                    Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Tell us your thoughts...',
                        prefixIcon: Icon(Icons.message, color: Colors.blue.shade700),
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
                      maxLines: 6,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          CloudLogger().warn('Message validation failed', {
                            'eventType': 'FORM_VALIDATION',
                            'field': 'message',
                            'reason': 'EMPTY_FIELD',
                            'userId': widget.user.uid
                          });
                          return 'Please enter your feedback';
                        }
                        if (value.trim().length < 10) {
                          CloudLogger().warn('Message validation failed', {
                            'eventType': 'FORM_VALIDATION',
                            'field': 'message',
                            'reason': 'TOO_SHORT',
                            'length': value.trim().length,
                            'userId': widget.user.uid
                          });
                          return 'Please provide more details (at least 10 characters)';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Log only when significant changes occur to reduce noise
                        if (value.length == 20 || value.length % 50 == 0) {
                          CloudLogger().debug('Message input updated', {
                            'eventType': 'FORM_INPUT',
                            'field': 'message',
                            'length': value.length,
                            'userId': widget.user.uid
                          });
                        }
                      },
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56.0,
                      child: ElevatedButton(
                        onPressed: _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send),
                            SizedBox(width: 8),
                            Text(
                              'Submit Feedback',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56.0,
                      child: OutlinedButton(
                        onPressed: () {
                          CloudLogger().userAction('feedback_cancelled', {
                            'feedbackType': _feedbackType,
                            'subjectFilled': _subjectController.text.isNotEmpty,
                            'messageFilled': _messageController.text.isNotEmpty,
                            'userId': widget.user.uid
                          });
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade700),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Privacy notice
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.privacy_tip, color: Colors.blue.shade700),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your feedback will be associated with your account to help us address your concerns better.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 40),
          
          // App info
          Text(
            'GoTask v1.0.0',
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          
          SizedBox(height: 24),
        ],
      ),
    );
  }
}