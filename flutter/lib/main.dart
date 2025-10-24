import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE MCU Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BLEHomePage(),
    );
  }
}

class BLEHomePage extends StatefulWidget {
  const BLEHomePage({super.key});

  @override
  State<BLEHomePage> createState() => _BLEHomePageState();
}

class _BLEHomePageState extends State<BLEHomePage> {
  final FlutterBluePlus flutterBlue = FlutterBluePlus();

  bool isScanning = false;
  bool isConnected = false;
  String latestValue = "No data yet";
  double goalHumidity = 50;
  double currentHumidity = 0;
  double offset = 1;
  bool isDeviceOn = false;
  BluetoothDevice? connectedDevice;

  // Your MCU device name (advertised from STM32 firmware)
  static const String targetDeviceName = "MY BLE DEVICE";

  // Try to connect directly to your known MCU
  Future<void> connectToKnownDevice() async {
    setState(() {
      isScanning = true;
      latestValue = "Searching for $targetDeviceName...";
    });

    await FlutterBluePlus.stopScan();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

    FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {
        debugPrint("device platformName: ${r.device.platformName}");
        if (r.device.platformName == targetDeviceName) {
          await FlutterBluePlus.stopScan();
          // await subscription.cancel();
          debugPrint("✅ Found known device: ${r.device.platformName}");
          connectToDevice(r.device);
          return;
        }
      }
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning) {
        setState(() {
          isScanning = false;
          if (!isConnected) {
            latestValue = "Device not found. Make sure $targetDeviceName is on.";
          }
        });
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      setState(() {
        connectedDevice = device;
        isConnected = true;
        latestValue = "Connected";
      });

      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.lastValueStream.listen((value) {
              if (characteristic.uuid.toString().toUpperCase().contains("2A6F")) {
                int raw = value[0] | (value[1] << 8);
                double humidity = raw / 100.0;
                setState(() {
                  // latestValue =
                  //     "Current 💧: ${humidity.toStringAsFixed(1)}%";
                  currentHumidity = humidity;
                });
                debugPrint("💧 Humidity: $humidity %, goalHumidity: $goalHumidity ");
                if(isDeviceOn && goalHumidity + offset < humidity) {
                  sendCommandToMCU(false); // turn off
                  setState(() {
                    isDeviceOn = false;
                  }); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.blueGrey,
                      content: Text("💧 Device turned off (humidity too high)"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else if(!isDeviceOn && goalHumidity - offset > humidity) {
                  sendCommandToMCU(true); // turn on
                  setState(() {
                    isDeviceOn = true;
                  }); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.blueAccent,
                      content: Text("💨 Device turned on (humidity too low)"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            });
          } else if (characteristic.properties.read) {
            var value = await characteristic.read();
            setState(() {
              latestValue =
                  "Characteristic ${characteristic.uuid} → ${value.toString()}";
            });
          }
        }
      }


    } catch (e) {
      debugPrint("❌ Connection error: $e");
      setState(() => latestValue = "Connection failed: $e");
    }
  }

  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      setState(() {
        isConnected = false;
        connectedDevice = null;
        latestValue = "Click 🔗 to connect to your MCU";
      });
    }
  }

  Future<void> sendCommandToMCU(bool turnOn) async {
    if (connectedDevice == null) return;

    List<BluetoothService> services = await connectedDevice!.discoverServices();

    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse) {

          // Optionally filter by UUID
          if (characteristic.uuid.toString().toUpperCase().contains("2A56")) {
            final command = turnOn ? [1] : [0];
            await characteristic.write(command, withoutResponse: true);
            debugPrint("Sent command: ${command[0]} to ${characteristic.uuid}");
            return;
          }
        }
      }
    }

    debugPrint("❌ No writable characteristic found.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HUMIDIFIER CONTROLLER"),
        actions: [
          if (!isConnected)
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: "Connect to MCU",
              onPressed: connectToKnownDevice,
            ),
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: disconnectDevice,
              tooltip: "Disconnect",
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                latestValue,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              // Text(
              //   connectedDevice?.platformName ?? targetDeviceName,
              //   style:
              //       const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              // ),
              const SizedBox(height: 30),
              // Text(
              //   "Latest Value:",
              //   style: Theme.of(context).textTheme.titleMedium,
              // ),
              const SizedBox(height: 10),
              if (isConnected) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: label + value
                    Text(
                      "Goal 💧      : ${goalHumidity.toStringAsFixed(0)}%",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Right: arrow buttons
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_downward, color: Colors.blueGrey),
                          onPressed: () {
                            setState(() {
                              goalHumidity = (goalHumidity - 1).clamp(0, 100);
                            });
                          },
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_upward, color: Colors.blueAccent),
                          onPressed: () {
                            setState(() {
                              goalHumidity = (goalHumidity + 1).clamp(0, 100);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),// simpler than vertical margin in next container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Current 💧 : ${currentHumidity.toStringAsFixed(1)}%",
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Turn On button
              Container(
                margin: const EdgeInsets.only(top: 60, bottom: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDeviceOn ? Colors.blueGrey : Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    setState(() {
                      isDeviceOn = !isDeviceOn;
                    });
                    await sendCommandToMCU(isDeviceOn);
                  },
                  child: Text(
                    isDeviceOn ? "Turn Off" : "Turn On",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              ],
              const SizedBox(height: 30),
              if (isScanning)
                const CircularProgressIndicator()
              // else if (!isConnected)
              //   TextButton.icon(
              //     icon: const Icon(Icons.search),
              //     label: const Text("Scan again"),
              //     onPressed: connectToKnownDevice,
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}
