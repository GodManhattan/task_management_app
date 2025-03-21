import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ErrorPage extends StatelessWidget {
  final String? errorMessage;

  const ErrorPage({super.key, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to initialize the app',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Restart the app properly
                      SystemNavigator.pop();
                    },
                    child: const Text('Close App'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
