import 'package:blood_on_the_clocktower/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;
  String? _message; // Variable für Feedback-Nachricht

  @override
  Widget build(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFc9f2f8),
      appBar: AppBar(
        title: Text(
            _isLoginMode ? localizedStrings.login : localizedStrings.register,
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              alignment: Alignment.bottomCenter,
              image: AssetImage(
                  'assets/images/backgrounds/background_grim_top.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                  'assets/images/backgrounds/background_grim_middel.jpg'), // Path to your background image
              fit: BoxFit
                  .cover, // Ensures the image covers the entire background
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Eingabefelder für E-Mail und Passwort
                  TextField(
                    cursorColor: Colors.white,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                        labelText: localizedStrings.email,
                        labelStyle: TextStyle(color: Colors.white)),
                    controller: _emailController,
                    onChanged:
                        _updateButtonState, // Überprüfe den Status bei jeder Eingabe
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    cursorColor: Colors.white,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                        labelText: localizedStrings.password,
                        labelStyle: TextStyle(color: Colors.white)),
                    controller: _passwordController,
                    obscureText: true,
                    onChanged:
                        _updateButtonState, // Überprüfe den Status bei jeder Eingabe
                  ),
                  const SizedBox(height: 20),
                  if (_message != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 16.0),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        color: Colors.black,
                      ),
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isInputValid()
                        ? () => _submit(authService)
                        : null, // Deaktiviert, wenn ungültig
                    style: ElevatedButton.styleFrom(
                        disabledBackgroundColor:
                            Color(0xFF4a3b5e).withOpacity(0.5),
                        disabledForegroundColor: Colors.grey,
                        backgroundColor: Color(0xFF4a3b5e).withOpacity(0.9),
                        foregroundColor: Colors.white),
                    child: Text(_isLoginMode
                        ? localizedStrings.login
                        : localizedStrings.register),
                  ),
                  const SizedBox(height: 80),
                  const SizedBox(height: 80),
                  const SizedBox(height: 80),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode =
                            !_isLoginMode; // Wechseln zwischen Anmelden und Registrieren
                        _message = null; // Nachricht zurücksetzen
                      });
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4a3b5e).withOpacity(0.9),
                        foregroundColor: Colors.white),
                    child: Text(_isLoginMode
                        ? localizedStrings.switchToRegister
                        : localizedStrings.switchToLogin),
                  ),
                  // Zeige Rückmeldung an
                ],
              ),
            ),
          ),
        )
      ]),
    );
  }

  // Überprüfe, ob die Eingaben gültig sind
  bool _isInputValid() {
    return _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  // Aktualisiere den Button-Status basierend auf den Eingaben
  void _updateButtonState(String value) {
    setState(() {
      // Der Zustand wird automatisch aktualisiert, wenn sich die Eingaben ändern
    });
  }

  Future<void> _submit(AuthService authService) async {
    setState(() {
      _message = null; // Zurücksetzen der Nachricht
    });

    try {
      if (_isLoginMode) {
        await authService.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
        // Nach erfolgreicher Anmeldung zurück navigieren
        Navigator.pop(context);
      } else {
        await authService.registerWithEmail(
          _emailController.text,
          _passwordController.text,
        );
        // Nach erfolgreicher Registrierung direkt anmelden
        await authService.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
        // Nach erfolgreicher Anmeldung zurück navigieren
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      // Spezifische Firebase-Fehlerbehandlung
      setState(() {
        _message = e.message; // Setze die spezifische Fehlermeldung
        print(
            "Fehlermeldung: ${e.code}: ${_message}"); // Fehlerdetails in der Konsole
      });
    } catch (e) {
      // Allgemeine Fehlerbehandlung
      setState(() {
        _message =
            "Ein unerwarteter Fehler ist aufgetreten."; // Allgemeine Fehlermeldung
        print(
            "Allgemeiner Fehler: ${e.toString()}"); // Ausgabe der Fehlermeldung in der Konsole
      });
    }
  }
}
