import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gotask/services/cloud_logger.dart';

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
  
  // Loading and error states
  bool _isLoading = true;
  String _errorMessage = '';
  
  // List to store FAQ items from Firestore
  List<Map<String, String>> _faqItems = [];
  
  @override
  void initState() {
    super.initState();
    CloudLogger().pageView('FAQPage', {
      'source': 'initState'
    });
    _loadFAQsFromFirestore();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    CloudLogger().debug('FAQPage disposed', {
      'eventType': 'PAGE_LIFECYCLE',
      'action': 'PAGE_DISPOSED'
    });
    super.dispose();
  }
  
  // Load FAQs from Firestore with detailed logging
  Future<void> _loadFAQsFromFirestore() async {
    final stopwatch = Stopwatch()..start();
    
    CloudLogger().info('Loading FAQs from Firestore', {
      'eventType': 'DATA_FETCH',
      'action': 'LOAD_FAQS_STARTED'
    });
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    
      // Fetch FAQ documents from Firestore
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('FAQ')
          .get();

      // Process query results
      List<Map<String, String>> loadedFaqs = [];
      
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Extract question and answer fields from each document
        loadedFaqs.add({
          'question': data['question'] ?? 'No question provided',
          'answer': data['answer'] ?? 'No answer provided',
        });
      }
          
      setState(() {
        _faqItems = loadedFaqs;
        _expandedList = List.generate(loadedFaqs.length, (index) => false);
        _isLoading = false;
      });
      
      stopwatch.stop();
      CloudLogger().info('FAQs loaded successfully', {
        'eventType': 'DATA_FETCH',
        'action': 'LOAD_FAQS_COMPLETED',
        'faqCount': loadedFaqs.length,
        'durationMs': stopwatch.elapsedMilliseconds
      });
    } catch (e, stackTrace) {
      stopwatch.stop();
      CloudLogger().error('Failed to load FAQs', {
        'eventType': 'DATA_FETCH',
        'action': 'LOAD_FAQS_ERROR',
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'durationMs': stopwatch.elapsedMilliseconds
      });

      setState(() {
        _errorMessage = 'Failed to load FAQs: $e';
        _isLoading = false;
      });
    }
  }
  
  // Filter FAQ items based on search query
  List<Map<String, String>> get _filteredFaqItems {
    if (_searchQuery.isEmpty) {
      return _faqItems;
    }
    
    final query = _searchQuery.toLowerCase();
    final filteredItems = _faqItems.where((item) {
      return item['question']!.toLowerCase().contains(query) ||
             item['answer']!.toLowerCase().contains(query);
    }).toList();
    
    // Only log when search is performed, not on every rebuild
    if (_searchQuery.length > 2) {  // Only log substantial searches
      CloudLogger().info('FAQ search performed', {
        'eventType': 'USER_SEARCH',
        'searchQuery': _searchQuery,
        'resultCount': filteredItems.length,
        'totalFaqs': _faqItems.length
      });
    }
    
    return filteredItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // This helps with keyboard appearance
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
          onPressed: () {
            CloudLogger().userAction('faq_page_back_button_pressed', {});
            Navigator.of(context).pop();
          },
        ),
        actions: [
          // Refresh button to reload FAQs
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              CloudLogger().userAction('faq_refresh_button_pressed', {
                'currentFaqCount': _faqItems.length,
                'hasSearchQuery': _searchQuery.isNotEmpty
              });
              _loadFAQsFromFirestore();
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
          child: GestureDetector(
            onTap: () {
              // Dismiss keyboard when tapping outside of text field
              FocusScope.of(context).unfocus();
            },
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need Help?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Find answers to common questions about GoTask',
                        style: TextStyle(
                          fontSize: 14,
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
                        suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                CloudLogger().userAction('faq_search_cleared', {
                                  'previousQuery': _searchQuery,
                                  'queryLength': _searchQuery.length
                                });
                                
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                // Dismiss keyboard
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        // Only log substantial changes to reduce noise
                        if (value.isEmpty && _searchQuery.isNotEmpty) {
                          CloudLogger().userAction('faq_search_cleared_by_typing', {
                            'previousQuery': _searchQuery
                          });
                        } else if (value.length == 3 || value.length % 5 == 0) {
                          // Log at 3 chars and then every 5 chars
                          CloudLogger().userAction('faq_search_typing', {
                            'queryLength': value.length
                          });
                        }
                        
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                ),
                
                // FAQ List - Wrapped in Expanded + Flexible to handle keyboard
                Flexible(
                  child: _isLoading 
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : _errorMessage.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
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
                                  'Error Loading FAQs',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _errorMessage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    CloudLogger().userAction('faq_retry_button_pressed', {
                                      'previousError': _errorMessage
                                    });
                                    _loadFAQsFromFirestore();
                                  },
                                  icon: Icon(Icons.refresh),
                                  label: Text('Try Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _faqItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.question_answer,
                                  size: 60,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No FAQs Found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Please check back later',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredFaqItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No matching questions found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    'Try a different search term',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () {
                                CloudLogger().userAction('faq_pull_to_refresh', {});
                                return _loadFAQsFromFirestore();
                              },
                              color: Colors.blue.shade700,
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: _filteredFaqItems.length,
                                itemBuilder: (context, index) {
                                  // Adjust the expanded state list if needed
                                  if (_expandedList.length <= index) {
                                    _expandedList.add(false);
                                  }
                                  
                                  final faqItem = _filteredFaqItems[index];
                                  
                                  return Card(
                                    margin: EdgeInsets.only(bottom: 8),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ExpansionTile(
                                      initiallyExpanded: _expandedList[index],
                                      onExpansionChanged: (expanded) {
                                        if (expanded) {
                                          CloudLogger().userAction('faq_item_expanded', {
                                            'question': faqItem['question']?.substring(0, Math.min(50, faqItem['question']!.length)),
                                            'position': index + 1,  // 1-based position for better readability
                                            'totalVisible': _filteredFaqItems.length,
                                            'fromSearch': _searchQuery.isNotEmpty
                                          });
                                        }
                                        
                                        setState(() {
                                          _expandedList[index] = expanded;
                                        });
                                      },
                                      title: Text(
                                        faqItem['question']!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                      trailing: Icon(
                                        _expandedList[index] ? Icons.remove : Icons.add,
                                        color: Colors.blue.shade700,
                                      ),
                                      children: [
                                        Text(
                                          faqItem['answer']!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade800,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
                
                // Footer - Wrapped in Visibility to hide when keyboard is open
                Visibility(
                  visible: MediaQuery.of(context).viewInsets.bottom == 0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          'Still have questions?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            CloudLogger().userAction('feedback_button_pressed', {
                              'source': 'FAQPage',
                              'searchPerformed': _searchQuery.isNotEmpty,
                              'faqsViewed': _expandedList.where((expanded) => expanded).length
                            });
                            
                            // Navigate to feedback page when pressed
                            Navigator.of(context).pop();
                            // Add navigation to feedback page here
                          },
                          icon: Icon(Icons.feedback_outlined),
                          label: Text('Send Feedback'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Simple Math utility for min function
class Math {
  static int min(int a, int b) => a < b ? a : b;
}