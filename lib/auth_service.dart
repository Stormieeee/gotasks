import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
    ], 
  );

Future<UserCredential?> signInWithGoogle() async {
  try {
    print("Starting Google Sign In process...");
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
    print("Google Sign In result: ${googleUser?.email ?? 'No user selected'}");
    
    if (googleUser == null) return null;

    print("Getting authentication details...");
    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    print("Got authentication details. Access token exists: ${googleAuth.accessToken != null}");

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    print("Signing in to Firebase with credentials...");
    // Sign in with the credential
    final userCredential = await _auth.signInWithCredential(credential);
    print("Successfully signed in: ${userCredential.user?.displayName}");
    
    return userCredential;
  } catch (e) {
    print('Error signing in with Google: $e');
    return null;
  }
}

  // Get Google Calendar client
  Future<calendar.CalendarApi?> getCalendarApi() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    if (googleUser == null) {
      return null;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;

    if (accessToken == null) {
      return null;
    }

    final authClient = AuthClient(
      http.Client(),
      accessToken,
    );

    return calendar.CalendarApi(authClient);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

// Helper class for authenticated HTTP requests
class AuthClient extends http.BaseClient {
  final http.Client _client;
  final String _accessToken;

  AuthClient(this._client, this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }
}