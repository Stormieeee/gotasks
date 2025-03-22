import 'package:flutter/material.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({Key? key}) : super(key: key);

  @override
  _FAQPageState createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  // Track which FAQ items are expanded
  List<bool> _expandedList = [];
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // List of FAQ items with questions and answers
  final List<Map<String, String>> _faqItems = [
    {
      'question': 'How do I create a new event?',
      'answer': 'To create a new event, go to the Calendar view and tap on the "+" floating action button. Fill in the event details such as title, description, date, time, and optional location. Tap "Create Event" to save your new event to your calendar.'
    },
    {
      'question': 'Can I edit existing events?',
      'answer': 'Yes, you can edit any event you\'ve created. Simply tap on the event in the Calendar view, then tap the "Edit" button. Make your changes in the edit form and tap "Update Event" to save your changes.'
    },
    {
      'question': 'How do I connect my Google Calendar?',
      'answer': 'GoTask automatically connects to your Google Calendar when you sign in with your Google account. All events you create in GoTask will sync with your Google Calendar, and events from Google Calendar will appear in GoTask.'
    },
    {
      'question': 'Why do I need to sign in with Google?',
      'answer': 'Signing in with Google allows GoTask to securely access your Google Calendar and provide seamless synchronization. This ensures your events are available across all your devices and in the Google Calendar app or website.'
    },
    {
      'question': 'How do I send feedback or report a bug?',
      'answer': 'To send feedback or report a bug, go to your Profile page and tap on "Send Feedback". Choose the type of feedback (suggestion, bug report, etc.), enter a subject and detailed message, then tap "Submit Feedback". Our team will review your feedback as soon as possible.'
    },
    {
      'question': 'Is my data secure?',
      'answer': 'Yes, GoTask takes data security seriously. We use Firebase Authentication for secure sign-in and all data is stored in Google\'s secure cloud infrastructure. Your calendar data is only accessible to you and anyone you\'ve explicitly shared your Google Calendar with.'
    },
    {
      'question': 'How do I log out of the app?',
      'answer': 'To log out, navigate to your Profile page and scroll down to find the "Sign Out" button. Tap it and confirm that you want to sign out. This will securely end your session and return you to the login screen.'
    },
    {
      'question': 'Can I use GoTask offline?',
      'answer': 'GoTask requires an internet connection for most features since it syncs with Google Calendar. However, once loaded, you can view your events offline. Creating or editing events requires an internet connection to ensure your changes sync properly.'
    },
    {
      'question': 'How do I validate a location for an event?',
      'answer': 'When creating or editing an event, enter a location in the location field. You can tap the search icon next to the field to validate that the location exists. GoTask will attempt to geocode the address and confirm if it\'s valid.'
    },
    {
      'question': 'Does GoTask send notifications for events?',
      'answer': 'Yes, GoTask can send you notifications for upcoming events. You can manage your notification preferences in the Settings page. By default, notifications follow your Google Calendar notification settings.'
    },
    {
      'question': 'How can I view events by day, week, or month?',
      'answer': 'In the Calendar view, you can switch between day, week, and month views using the tabs at the top of the screen. This allows you to choose the time frame that works best for your planning needs.'
    },
    {
      'question': 'Can I share events with others?',
      'answer': 'Currently, event sharing is handled through Google Calendar. Create your event in GoTask, and then use Google Calendar to invite others or share the event details.'
    }
  ];
  
  @override
  void initState() {
    super.initState();
    // Initialize all FAQ items as collapsed
    _expandedList = List.generate(_faqItems.length, (index) => false);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Filter FAQ items based on search query
  List<Map<String, String>> get _filteredFaqItems {
    if (_searchQuery.isEmpty) {
      return _faqItems;
    }
    
    final query = _searchQuery.toLowerCase();
    return _faqItems.where((item) {
      return item['question']!.toLowerCase().contains(query) ||
             item['answer']!.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
        title: Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
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
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Help?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Find answers to common questions about GoTask',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Search Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search questions...',
                      prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
              
              // FAQ List
              Expanded(
                child: _filteredFaqItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No matching questions found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _filteredFaqItems.length,
                      itemBuilder: (context, index) {
                        // Adjust the expanded state list if needed
                        if (_expandedList.length <= index) {
                          _expandedList.add(false);
                        }
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _expandedList[index],
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _expandedList[index] = expanded;
                              });
                            },
                            title: Text(
                              _filteredFaqItems[index]['question']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                                fontSize: 16,
                              ),
                            ),
                            tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            expandedCrossAxisAlignment: CrossAxisAlignment.start,
                            trailing: Icon(
                              _expandedList[index] ? Icons.remove : Icons.add,
                              color: Colors.blue.shade700,
                            ),
                            children: [
                              Text(
                                _filteredFaqItems[index]['answer']!,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
              
              // Footer
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    Text(
                      'Still have questions?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to feedback page when pressed
                        Navigator.of(context).pop();
                        // Add navigation to feedback page here
                      },
                      icon: Icon(Icons.feedback_outlined),
                      label: Text('Send Feedback'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
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
            ],
          ),
        ),
      ),
    );
  }
}