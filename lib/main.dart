import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

void main() {
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
          channelKey: "basic_channel",
          channelName: "Basic notifications",
          channelDescription: "Basic test notification channel"),
      NotificationChannel(
          channelKey: "greater_channel",
          channelName: "Greater notifications",
          channelDescription: "Notification channel for warnings"),
    ],
    debug: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

String _lastReceivedData = '';
bool _notificationSent = false;
bool _pillReadyNotificationSent = false;
bool _pillWarningNotificationSent = false;

final RegExp _floatingPointRegExp = RegExp(r'^\d*\.?\d*$');
final _floatingPointFormatter = FilteringTextInputFormatter.allow(_floatingPointRegExp);

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

  int _selectedHour1 = 0;
  int _selectedMinute1 = 0;
  int _selectedSecond1 = 0;

  int _selectedHour2 = 0;
  int _selectedMinute2 = 0;
  int _selectedSecond2 = 0;

  int _selectedHour3 = 0;
  int _selectedMinute3 = 0;
  int _selectedSecond3 = 0;

  int _selectedHour4 = 0;
  int _selectedMinute4 = 0;
  int _selectedSecond4 = 0;

  List<int> _timesInSeconds = [];

  final TextEditingController _cycleController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();

  


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

  void _sendNotificationPillReady() {
    Future.delayed(Duration(seconds: 0), () {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 5,
          channelKey: 'basic_channel',
          title: 'Pills are ready',
          body: 'Your pills have been dispensed.',
          largeIcon: 'asset://assets/kek.png',
        ),
      );
    });
  }

  void _sendNotificationPillWarning() {
    Future.delayed(Duration(seconds: 0), () {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 6,
          channelKey: 'greater_channel',
          title: 'Non-Ideal Pill Conditions',
          body:
              'Please check the temperature and humidity values of the pillbox.',
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

        if (_receivedData.contains("n1")) {
          _sendNotificationPillReady();
        } else if (_receivedData.contains("n2")) {
          _sendNotificationPillWarning();
        }
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
            "Pill Dispense-matic App",
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
              if (_receivedData != "n1" && _receivedData != "n2")
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
                            backgroundColor: Colors.yellow,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              side: BorderSide(color: Colors.blue),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                          ),
                          child: Text(
                            "Dispense",
                            style: TextStyle(
                              color: _deviceStatus == Device.connected
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        
                        SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _cycleController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 8),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true), // Enable decimal input
                              inputFormatters: <TextInputFormatter>[
                                _floatingPointFormatter,
                              ],
                              ),
                            ),
                            SizedBox(width: 30),
                            TextButton(
                              onPressed: _deviceStatus == Device.connected 
                                  ? () async {
                                      _intervalSection();
                                    }
                                  : null,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.pink,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  side: BorderSide(color: Colors.red),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                              ),
                              child: Text(
                                "Intervals",
                                style: TextStyle(
                                  color: _deviceStatus == Device.connected
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
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

              SizedBox(height: 20), // Space between buttons and new widgets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    "Max Humidity:  ",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _humidityController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      sendHumidityToDevice();
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.blue,
                      onPrimary: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      textStyle:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: Text("Submit"),
                  ),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    "Max Temp (C*):",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _temperatureController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      sendTemperatureToDevice();
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.blue,
                      onPrimary: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      textStyle:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: Text("Submit"),
                  ),
                ],
              ),
              SizedBox(height:20),
              ElevatedButton(
                    onPressed: () {
                      _resetBlink();
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.blue,
                      onPrimary: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      textStyle:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: Text("Restart Humidity/Temp Controller"),
                  ),

              SizedBox(height: 20),
              // First set of dropdowns
              _buildTimeDropdowns(1),
              SizedBox(height: 20),
              // Second set of dropdowns
              _buildTimeDropdowns(2),
              SizedBox(height: 20),
              // Third set of dropdowns
              _buildTimeDropdowns(3),
              SizedBox(height: 20),
              // Fourth set of dropdowns
              _buildTimeDropdowns(4),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _calculateTimes,
                child: Text('Set Dispense Times'),
              ),
              SizedBox(height: 20),
              if (_timesInSeconds.isNotEmpty) ...[
                for (var timeInSeconds in _timesInSeconds)
                  Column(
                    children: [
                      Text(
                          "Time difference: ${_formatTimeDifference(timeInSeconds)}"),
                    ],
                  )
              ],

              if (_timesInSeconds.isNotEmpty) ...[
                Container(
                  child: Column(
                    children: [
                      // Create a function to build the concatenated text
                      _buildConcatenatedText(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConcatenatedText() {
    String concatenatedText = '';
    for (int index = 0; index < _timesInSeconds.length; index++) {
      concatenatedText +=
          "p$index${_formatMilliseconds(_timesInSeconds[index] * 1000)} ";
    }
    print(concatenatedText);
    return Text(concatenatedText);
  }

  Widget _buildTimeDropdowns(int setNumber) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // Hour dropdown
        DropdownButton<int>(
          value: _getSelectedHour(setNumber),
          onChanged: (int? newValue) {
            setState(() {
              _setSelectedHour(setNumber, newValue!);
            });
          },
          items: List<DropdownMenuItem<int>>.generate(24, (int index) {
            return DropdownMenuItem<int>(
              value: index,
              child: Text('$index'),
            );
          }),
        ),
        SizedBox(width: 10),
        Text(':'),
        SizedBox(width: 10),
        // Minute dropdown
        DropdownButton<int>(
          value: _getSelectedMinute(setNumber),
          onChanged: (int? newValue) {
            setState(() {
              _setSelectedMinute(setNumber, newValue!);
            });
          },
          items: List<DropdownMenuItem<int>>.generate(60, (int index) {
            return DropdownMenuItem<int>(
              value: index,
              child: Text('$index'),
            );
          }),
        ),
        SizedBox(width: 10),
        Text(':'),
        SizedBox(width: 10),
        DropdownButton<int>(
          value: _getSelectedSecond(setNumber),
          onChanged: (int? newValue) {
            setState(() {
              _setSelectedSecond(setNumber, newValue!);
            });
          },
          items: List<DropdownMenuItem<int>>.generate(60, (int index) {
            return DropdownMenuItem<int>(
              value: index,
              child: Text('$index'),
            );
          }),
        ),
        SizedBox(width: 10),
        // Label for the set
        Text(
          'Set $setNumber',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  int _getSelectedHour(int setNumber) {
    switch (setNumber) {
      case 1:
        return _selectedHour1;
      case 2:
        return _selectedHour2;
      case 3:
        return _selectedHour3;
      case 4:
        return _selectedHour4;
      default:
        return 0;
    }
  }

  int _getSelectedMinute(int setNumber) {
    switch (setNumber) {
      case 1:
        return _selectedMinute1;
      case 2:
        return _selectedMinute2;
      case 3:
        return _selectedMinute3;
      case 4:
        return _selectedMinute4;
      default:
        return 0;
    }
  }

  int _getSelectedSecond(int setNumber) {
    switch (setNumber) {
      case 1:
        return _selectedSecond1;
      case 2:
        return _selectedSecond2;
      case 3:
        return _selectedSecond3;
      case 4:
        return _selectedSecond4;
      default:
        return 0;
    }
  }

  void _setSelectedHour(int setNumber, int value) {
    switch (setNumber) {
      case 1:
        _selectedHour1 = value;
        break;
      case 2:
        _selectedHour2 = value;
        break;
      case 3:
        _selectedHour3 = value;
        break;
      case 4:
        _selectedHour4 = value;
        break;
      default:
    }
  }

  void _setSelectedMinute(int setNumber, int value) {
    switch (setNumber) {
      case 1:
        _selectedMinute1 = value;
        break;
      case 2:
        _selectedMinute2 = value;
        break;
      case 3:
        _selectedMinute3 = value;
        break;
      case 4:
        _selectedMinute4 = value;
        break;
      default:
    }
  }

  void _setSelectedSecond(int setNumber, int value) {
    switch (setNumber) {
      case 1:
        _selectedSecond1 = value;
        break;
      case 2:
        _selectedSecond2 = value;
        break;
      case 3:
        _selectedSecond3 = value;
        break;
      case 4:
        _selectedSecond4 = value;
        break;
      default:
    }
  }

  void _calculateTimes() {
    final now = DateTime.now();

    final selectedTimes = [
      DateTime(now.year, now.month, now.day, _selectedHour1, _selectedMinute1,
          _selectedSecond1),
      DateTime(now.year, now.month, now.day, _selectedHour2, _selectedMinute2,
          _selectedSecond2),
      DateTime(now.year, now.month, now.day, _selectedHour3, _selectedMinute3,
          _selectedSecond3),
      DateTime(now.year, now.month, now.day, _selectedHour4, _selectedMinute4,
          _selectedSecond4),
    ];

    _timesInSeconds = selectedTimes.map((time) {
      if (time.isBefore(now)) {
        time = time.add(Duration(days: 1));
      }
      return time.difference(now).inSeconds;
    }).toList();

    _timesInSeconds.sort();

    setState(() {});

    _sendConcatenatedTextToDevice();
  }

  void sendHumidityToDevice() async {
    String humidityText = "h${_humidityController.text}";
    await _bluetoothClassicPlugin.write(humidityText);
  }

  void sendTemperatureToDevice() async {
    String temperatureText = "t${_temperatureController.text}";
    await _bluetoothClassicPlugin.write(temperatureText);
  }

  String _formatTimeDifference(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$hours hours, $minutes minutes, $remainingSeconds seconds';
  }

  String _formatMilliseconds(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final remainingMilliseconds = milliseconds % 1000;
    return '$milliseconds';
  }

  void _sendConcatenatedTextToDevice() async {
    for (int index = 0; index < _timesInSeconds.length; index++) {
      String lastSent =
          "p$index${_formatMilliseconds(_timesInSeconds[index] * 1000)}\n";
      await _bluetoothClassicPlugin.write(lastSent);
    }

    await _bluetoothClassicPlugin.write("o");
  }


  void _intervalSection() async {
  String temperature = "i${_cycleController.text}";

  await _bluetoothClassicPlugin.write(temperature);
  }

  void _resetBlink() async {
 

  await _bluetoothClassicPlugin.write("y");
  }
}
