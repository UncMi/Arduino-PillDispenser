import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';

void main() {
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
          channelKey: "basic_channel",
          channelName: "Basic notifications",
          channelDescription: "Basic test notification channel"),
    ],
    debug: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _bluetoothClassicPlugin = BluetoothClassic();
  List<Device> _devices = [];
  List<Device> _discoveredDevices = [];
  bool _scanning = false;
  int _deviceStatus = Device.disconnected;
  Uint8List _data = Uint8List(0);

  bool _isRunning = false;
  String _receivedData = "";

  final TextEditingController _controller1Hour = TextEditingController();
  final TextEditingController _controller1Minute = TextEditingController();
  final TextEditingController _controller1Second = TextEditingController();
  final TextEditingController _controller2Hour = TextEditingController();
  final TextEditingController _controller2Minute = TextEditingController();
  final TextEditingController _controller2Second = TextEditingController();
  final TextEditingController _controller3Hour = TextEditingController();
  final TextEditingController _controller3Minute = TextEditingController();
  final TextEditingController _controller3Second = TextEditingController();
  final TextEditingController _controller4Hour = TextEditingController();
  final TextEditingController _controller4Minute = TextEditingController();
  final TextEditingController _controller4Second = TextEditingController();

  List<String> _results = [];
  String? _warningMessage;

  void _startCycle() async {
    setState(() {
      _isRunning = true;
    });
    for (int i = 0; i < 7; i++) {
      if (!_isRunning) {
        break;
      }
      await _bluetoothClassicPlugin.write('s');
      if (i < 6 && _isRunning) {
        await Future.delayed(Duration(seconds: 15));
      }
    }
    setState(() {
      _isRunning = false;
    });
  }

  void _stopCycle() {
    setState(() {
      _isRunning = false;
    });
  }

  void _sendNotification() {
    Future.delayed(Duration(seconds: 0), () {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 5,
          channelKey: 'basic_channel',
          title: 'Whoops',
          body: 'your pills are messed up',
          largeIcon: 'asset://assets/kek.png',
        ),
      );
    });
  }

  void _sendNotificationDelayed() {
    Future.delayed(Duration(seconds: 10), () {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 5,
          channelKey: 'basic_channel',
          title: 'Whoops',
          body: 'your pills are messed up',
          largeIcon: 'asset://assets/kek.png',
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    initPlatformState();
    _bluetoothClassicPlugin.onDeviceStatusChanged().listen((event) {
      setState(() {
        _deviceStatus = event;
      });
    });
    _bluetoothClassicPlugin.onDeviceDataReceived().listen((event) {
      setState(() {
        _data = event;
        _receivedData = String.fromCharCodes(_data);
      });
    });
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = await _bluetoothClassicPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _getDevices() async {
    var res = await _bluetoothClassicPlugin.getPairedDevices();
    setState(() {
      _devices = res;
    });
  }

  Future<void> _scan() async {
    if (_scanning) {
      await _bluetoothClassicPlugin.stopScan();
      setState(() {
        _scanning = false;
      });
    } else {
      await _bluetoothClassicPlugin.startScan();
      _bluetoothClassicPlugin.onDeviceDiscovered().listen(
        (event) {
          setState(() {
            _discoveredDevices = [..._discoveredDevices, event];
          });
        },
      );
      setState(() {
        _scanning = true;
      });
    }
  }

  Widget buildTimeInputField(
      TextEditingController hourController,
      TextEditingController minuteController,
      TextEditingController secondController,
      String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: int.tryParse(hourController.text),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: '$label Hour',
              ),
              items: List.generate(24, (index) => index)
                  .map((hour) => DropdownMenuItem<int>(
                        value: hour,
                        child: Text(hour.toString().padLeft(2, '0')),
                      ))
                  .toList(),
              onChanged: (value) {
                hourController.text = value.toString();
              },
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: int.tryParse(minuteController.text),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: '$label Minute',
              ),
              items: List.generate(60, (index) => index)
                  .map((minute) => DropdownMenuItem<int>(
                        value: minute,
                        child: Text(minute.toString().padLeft(2, '0')),
                      ))
                  .toList(),
              onChanged: (value) {
                minuteController.text = value.toString();
              },
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: int.tryParse(secondController.text),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: '$label Second',
              ),
              items: List.generate(60, (index) => index)
                  .map((second) => DropdownMenuItem<int>(
                        value: second,
                        child: Text(second.toString().padLeft(2, '0')),
                      ))
                  .toList(),
              onChanged: (value) {
                secondController.text = value.toString();
              },
            ),
          ),
        ],
      ),
    );
  }

  void calculateTimeDifferences() {
  setState(() {
    _results.clear();
    _warningMessage = null;

    // Parse the input times
    List<DateTime?> times = [
      parseTime(_controller1Hour.text, _controller1Minute.text, _controller1Second.text),
      parseTime(_controller2Hour.text, _controller2Minute.text, _controller2Second.text),
      parseTime(_controller3Hour.text, _controller3Minute.text, _controller3Second.text),
      parseTime(_controller4Hour.text, _controller4Minute.text, _controller4Second.text),
    ];

    // Get the current time
    DateTime now = DateTime.now();

    // Check and remove invalid times
    for (int i = 0; i < times.length; i++) {
      for (int j = i + 1; j < times.length; j++) {
        if (times[i] != null && times[j] != null && times[i]!.isAfter(times[j]!)) {
          times[i] = null;
          _warningMessage = 'Warning: Input ${i + 1} is later than Input ${j}';
          break;
        }
      }
    }

    // Filter out null values
    times = times.where((time) => time != null).toList();

    // Add the difference between now and the first valid time
    if (times.isNotEmpty && times[0] != null) {
      _results.add('Difference between now and input 0: ${now.difference(times[0]!).inSeconds} seconds');
    }

    // Check differences between remaining valid times
    for (int i = 0; i < times.length - 1; i++) {
      if (times[i] != null && times[i + 1] != null) {
        if (times[i]!.isAfter(times[i + 1]!)) {
          _warningMessage = 'Warning: Input ${i + 1} is later than Input ${i + 2}';
        } else {
          _results.add('Difference between input ${i + 1} and input ${i + 2}: ${times[i + 1]!.difference(times[i]!).inSeconds} seconds');
        }
      }
    }
  });
}

  DateTime? parseTime(String hour, String minute, String second) {
    if (hour.isEmpty || minute.isEmpty || second.isEmpty) return null;
    try {
      final now = DateTime.now();
      final time = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(hour),
        int.parse(minute),
        int.parse(second),
      );
      return time;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color.fromARGB(255, 46, 53, 52),
        textTheme: TextTheme(
          bodyText2: TextStyle(color: Colors.white),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            primary: Colors.white,
          ),
        ),
      ),
      home: Scaffold(
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
        body: SingleChildScrollView(
          child: Column(
            children: [
              Text("Device status is $_deviceStatus"),
              Row(
                children: [
                  SizedBox(width: 40),
                  TextButton(
                    onPressed: () async {
                      await _bluetoothClassicPlugin.initPermissions();
                    },
                    child: const Text("Check Permissions"),
                  ),
                  TextButton(
                    onPressed: _getDevices,
                    child: const Text("Get Paired Devices"),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(width: 87),
                  TextButton(
                    onPressed: _deviceStatus == Device.connected
                        ? () async {
                            await _bluetoothClassicPlugin.disconnect();
                          }
                        : null,
                    child: const Text("Disconnect"),
                  ),
                  TextButton(
                    onPressed: _deviceStatus == Device.connected
                        ? () async {
                            await _bluetoothClassicPlugin.write('s');
                          }
                        : null,
                    child: const Text("Send Ping"),
                  ),
                ],
              ),
              ...[
                for (var device in _devices)
                  TextButton(
                    onPressed: () async {
                      await _bluetoothClassicPlugin.connect(device.address,
                          "00001101-0000-1000-8000-00805f9b34fb");
                      setState(() {
                        _discoveredDevices = [];
                        _devices = [];
                      });
                    },
                    child: Text(device.name ?? device.address),
                  ),
              ],
              TextButton(
                onPressed: _scan,
                child: Text(_scanning ? "Stop Scan" : "Start Scan"),
              ),
              ...[
                for (var device in _discoveredDevices)
                  Text(device.name ?? device.address),
              ],
              Text("Received data: $_receivedData"),
              SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        TextButton(
                          onPressed: _deviceStatus == Device.connected
                              ? () async {
                                  await _bluetoothClassicPlugin.write('s');
                                }
                              : null,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              side: BorderSide(color: Colors.blue),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                          ),
                          child: Text(
                            "Section",
                            style: TextStyle(
                              color: _deviceStatus == Device.connected
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _deviceStatus == Device.connected &&
                                      !_isRunning
                                  ? () async {
                                      _startCycle();
                                    }
                                  : null,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  side: BorderSide(color: Colors.green),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                              ),
                              child: Text(
                                "Cycle Start",
                                style: TextStyle(
                                  color: _deviceStatus == Device.connected
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(width: 30),
                            TextButton(
                              onPressed: _deviceStatus == Device.connected &&
                                      _isRunning
                                  ? () async {
                                      _stopCycle();
                                    }
                                  : null,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  side: BorderSide(color: Colors.red),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                              ),
                              child: Text(
                                "Cycle Stop",
                                style: TextStyle(
                                  color: _deviceStatus == Device.connected
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Data: $_receivedData",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _sendNotification,
                child: Text('Send Notification'),
              ),
              ElevatedButton(
                onPressed: _sendNotificationDelayed,
                child: Text('Send Notification with delay'),
              ),
              buildTimeInputField(_controller1Hour, _controller1Minute,
                  _controller1Second, 'Input 1'),
              buildTimeInputField(_controller2Hour, _controller2Minute,
                  _controller2Second, 'Input 2'),
              buildTimeInputField(_controller3Hour, _controller3Minute,
                  _controller3Second, 'Input 3'),
              buildTimeInputField(_controller4Hour, _controller4Minute,
                  _controller4Second, 'Input 4'),
              ElevatedButton(
                onPressed: calculateTimeDifferences,
                child: Text('Calculate Time Differences'),
              ),
              if (_results.isNotEmpty)
                ..._results.map((result) => Text(result)),
              if (_warningMessage != null)
                Text(
                  _warningMessage!,
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
