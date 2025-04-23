import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _canEdit = false;

  AuthService() {
    // Bei der Initialisierung den Auth-Status überwachen
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (_user != null) {
        _loadUserPermissions(); // Permissions laden, falls eingeloggt
      } else {
        _canEdit = false; // Zurücksetzen bei Logout
      }
      notifyListeners(); // Änderungen melden
    });
  }

  // Getter für den aktuellen Benutzer
  User? get user => _user;

  // Getter für canEdit
  bool get canEdit => _canEdit;

  Future<void> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: e.message,
      );
    } catch (e) {
      throw Exception("Ein unerwarteter Fehler ist aufgetreten: $e");
    }
  }

  Future<void> registerWithEmail(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;

      // Speichere Benutzerinformationen in Firestore
      await _firestore.collection('users').doc(_user!.uid).set({
        'email': email,
        'canEdit': false, // Setze canEdit auf false
        // Hier kannst du weitere Benutzerdaten hinzufügen
      });
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: e.message,
      );
    } catch (e) {
      throw Exception("Ein unerwarteter Fehler ist aufgetreten: $e");
    }
  }

  // Einloggen mit Google
  Future<void> signInWithGoogle() async {
    try {
      print("Versuche, sich mit Google anzumelden...");

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        print("Kein Benutzer ausgewählt. Abbrechen.");
        return; // Abbrechen, wenn kein User ausgewählt wurde
      }

      print("Benutzer erfolgreich ausgewählt: ${googleUser.email}");

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      print("Google Authentifizierung erfolgreich.");

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print(
          "Versuche, Benutzer mit den bereitgestellten Anmeldeinformationen anzumelden...");
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      _user = userCredential.user;

      print("Benutzer erfolgreich angemeldet: ${_user?.email}");

      // Neuen Benutzer in Firestore speichern, wenn nicht existierend
      if (_user != null) {
        final userDoc = _firestore.collection('users').doc(_user!.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          print(
              "Benutzer existiert nicht in Firestore, daher neuen Benutzer hinzufügen...");
          await userDoc.set({
            'email': _user!.email,
            'displayName': _user!.displayName,
            'photoURL': _user!.photoURL,
            'canEdit': false, // Standardwert für canEdit
          });
          print("Benutzer erfolgreich in Firestore hinzugefügt.");
        } else {
          print("Benutzer existiert bereits in Firestore.");
        }

        await _loadUserPermissions(); // Berechtigungen laden
      }

      notifyListeners();
      print("Benutzerberechtigungen geladen und Listener benachrichtigt.");
    } catch (e) {
      print("Fehler beim Google Sign-In: $e");
    }
  }

  // Ausloggen
  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _canEdit = false;
    notifyListeners();
  }

  // Berechtigungen des aktuellen Benutzers laden
  Future<void> _loadUserPermissions() async {
    if (_user != null) {
      final userDoc =
          await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists) {
        _canEdit = userDoc.data()?['canEdit'] ?? false;
      } else {
        _canEdit = false;
      }
      notifyListeners(); // Listener informieren, dass sich die Berechtigungen geändert haben
    }
  }
}
