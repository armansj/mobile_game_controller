import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(GameControlApp());
}

class GameControlApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Game Control Server',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: GameControlScreen(),
    );
  }
}

class GameControlScreen extends StatefulWidget {
  @override
  _GameControlScreenState createState() => _GameControlScreenState();
}

class _GameControlScreenState extends State<GameControlScreen> {
  late HttpServer _server;
  List<WebSocket> _connectedClients = [];

  double _pitch = 0; // up/down tilt
  double _yaw = 0;   // left/right tilt
  double _roll = 0;  // rotation/turn

  @override
  void initState() {
    super.initState();
    startServer();

    // Listen to accelerometer data
    accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _pitch = event.x;  // Horizontal tilt (left/right)
        _yaw = event.y;    // Vertical tilt (up/down)
      });
    });

    // Listen to gyroscope data (for rotation)
    gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _roll = event.z;  // Rotation (turning)
      });

      // Broadcast orientation data to connected clients
      sendOrientationData();
    });
  }

  Future<void> startServer() async {
    _server = await HttpServer.bind('0.0.0.0', 12345);
    print("WebSocket server started on ws://${_server.address.address}:${_server.port}");

    _server.transform(WebSocketTransformer()).listen((WebSocket client) {
      print("New client connected");
      _connectedClients.add(client);

      client.done.then((_) {
        print("Client disconnected");
        _connectedClients.remove(client);
      });
    });
  }

  void sendOrientationData() {
    final message = jsonEncode({'pitch': _pitch, 'yaw': _yaw, 'roll': _roll});
    for (final client in _connectedClients) {
      client.add(message);
    }
  }

  @override
  void dispose() {
    for (final client in _connectedClients) {
      client.close();
    }
    _server.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Game Control Server')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Pitch: $_pitch, Yaw: $_yaw, Roll: $_roll'),
            ElevatedButton(
              onPressed: sendOrientationData,
              child: Text('Send Test Data'),
            ),
          ],
        ),
      ),
    );
  }
}
