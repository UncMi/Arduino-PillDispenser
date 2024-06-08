import 'package:flutter/material.dart';

class ArduinoScreen extends StatelessWidget {
  const ArduinoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "PillZapinator Connect",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 46, 53, 52),
      ),
      backgroundColor: Color.fromARGB(255, 76, 88, 87),
      body: Center(
        child: TextButton(
          onPressed: () {
            print("Button pressed!");
          },
          child: Text(
            "Connect",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: Color.fromARGB(255, 46, 53, 52),
          ),
        ),
      ),
    );
  }
}
