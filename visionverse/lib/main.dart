import 'package:flutter/material.dart';

import './MainPage.dart';

void main() => runApp(new ExampleApplication());

class ExampleApplication extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: SplashScreen());
  }
}


class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // _initializeBluetooth();
    _navigateToNextScreen();

    // Initialize the animation controller
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(); // Repeat the animation indefinitely
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose the animation controller
    super.dispose();
  }

  // Future<void> _initializeBluetooth() async {
  //   await FlutterBluetoothSerial.instance.requestEnable();
  // }

  void _navigateToNextScreen() {
    Future.delayed(Duration(seconds: 6), () {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainPage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Rotate the logo using RotationTransition
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
              child: ClipOval(
                child: Image.asset(
                  'logo.jpg',
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'VISION VERSE',
              style: TextStyle(
                fontFamily: 'Roboto', // Set the font family to 'Roboto'
                fontSize: 24, // Adjust the font size as needed
                fontWeight: FontWeight.bold, // You can also specify the font weight if desired
                color: Colors.lightBlueAccent, // Set the text color
              ),
            ),
          ],
        ),
      ),
    );
  }
}