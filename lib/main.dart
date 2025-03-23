import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gotask/services/cloud_logger.dart';
import 'services/firebase_options.dart';
import 'package:gotask/Pages/home_Page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await CloudLogger.init();

  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Log app build event
    CloudLogger().info('Application build started');
    
    final app = MaterialApp(
      title: 'GoTasks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomePage(title: 'GoTasks'),
      navigatorObservers: [
        // Add a route observer for logging navigation events
        RouteObserver<PageRoute>(),
      ],
      // Add route change logging
      onGenerateRoute: (settings) {
        CloudLogger().pageView(settings.name ?? 'unknown_route', {
          'arguments': settings.arguments?.toString(),
        });
        
        // Return null to let the normal routing happen
        return null;
      },
    );
    
    // Log app build completed
    CloudLogger().info('Application build completed');
    
    return app;
  }
}