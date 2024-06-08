import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';

void main() {
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

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _bluetoothClassicPlugin.onDeviceStatusChanged().listen((event) {
      setState(() {
        _deviceStatus = event;
      });
    });
    _bluetoothClassicPlugin.onDeviceDataReceived().listen((event) {
      setState(() {
        _data = Uint8List.fromList([..._data, ...event]);
        _receivedData = String.fromCharCodes(_data);
      });
    });
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = await _bluetoothClassicPlugin.getPlatformVersion() ?? 'Unknown platform version';
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
                      await _bluetoothClassicPlugin.connect(device.address, "00001101-0000-1000-8000-00805f9b34fb");
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
              Text("Received data: ${String.fromCharCodes(_data)}"),
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
                            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          ),
                          child: Text(
                            "Section",
                            style: TextStyle(
                              color: _deviceStatus == Device.connected ? Colors.white : Colors.grey, 
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _deviceStatus == Device.connected && !_isRunning
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
                                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              ),
                              child: Text(
                                "Cycle Start",
                                style: TextStyle(
                                  color: _deviceStatus == Device.connected ? Colors.white : Colors.grey, 
                                ),
                              ),
                            ),
                            SizedBox(width: 30),
                            TextButton(
                              onPressed: _deviceStatus == Device.connected && _isRunning
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
                                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              ),
                              child: Text(
                                "Cycle Stop",
                                style: TextStyle(
                                  color: _deviceStatus == Device.connected ? Colors.white : Colors.grey, 
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
                  "想說路: $_receivedData",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
