// SelectBondedDevicePage.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import './BluetoothDeviceListEntry.dart';
import './detailpage.dart';

class SelectBondedDevicePage extends StatefulWidget {
  final bool checkAvailability;
  final Function(String)? onIPAddressEntered;

  const SelectBondedDevicePage({this.checkAvailability = true, this.onIPAddressEntered});

  @override
  _SelectBondedDevicePage createState() => new _SelectBondedDevicePage();
}

enum _DeviceAvailability {
  no,
  maybe,
  yes,
}

class _DeviceWithAvailability {
  BluetoothDevice device;
  _DeviceAvailability availability;
  int? rssi;

  _DeviceWithAvailability(this.device, this.availability, [this.rssi]);
}

class _SelectBondedDevicePage extends State<SelectBondedDevicePage> {
  List<_DeviceWithAvailability> devices = List<_DeviceWithAvailability>.empty(growable: true);
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;
  bool _isDiscovering = false;

  _SelectBondedDevicePage();

  @override
  void initState() {
    super.initState();

    _isDiscovering = widget.checkAvailability;

    if (_isDiscovering) {
      _startDiscovery();
    }

    FlutterBluetoothSerial.instance.getBondedDevices().then((List<BluetoothDevice> bondedDevices) {
      setState(() {
        devices = bondedDevices
            .map(
              (device) => _DeviceWithAvailability(
            device,
            widget.checkAvailability ? _DeviceAvailability.maybe : _DeviceAvailability.yes,
          ),
        )
            .toList();
      });
    });
  }

  void _restartDiscovery() {
    setState(() {
      _isDiscovering = true;
    });

    _startDiscovery();
  }

  void _startDiscovery() {
    _discoveryStreamSubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
          setState(() {
            Iterator i = devices.iterator;
            while (i.moveNext()) {
              var _device = i.current;
              if (_device.device == r.device) {
                _device.availability = _DeviceAvailability.yes;
                _device.rssi = r.rssi;
              }
            }
          });
        });

    _discoveryStreamSubscription?.onDone(() {
      setState(() {
        _isDiscovering = false;
      });
    });
  }

  @override
  void dispose() {
    _discoveryStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController ipAddressController = TextEditingController();

    List<BluetoothDeviceListEntry> list = devices
        .map((_device) => BluetoothDeviceListEntry(
      device: _device.device,
      rssi: _device.rssi,
      enabled: _device.availability == _DeviceAvailability.yes,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DetailPage(server: _device.device, ipAddress: ipAddressController.text),
          ),
        );
      },
    ))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Select device'),
        actions: <Widget>[
          _isDiscovering
              ? FittedBox(
            child: Container(
              margin: new EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white,
                ),
              ),
            ),
          )
              : IconButton(
            icon: Icon(Icons.replay),
            onPressed: _restartDiscovery,
          )
        ],
      ),
      body: Column(
        children: [
          TextField(
            controller: ipAddressController,
            decoration: InputDecoration(
              labelText: 'Enter IP Address',
              hintText: 'e.g., 192.168.1.1',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (widget.onIPAddressEntered != null) {
                widget.onIPAddressEntered!(ipAddressController.text);
              }
            },
            child: Text('Connect'),
          ),
          Expanded(
            child: ListView(children: list),
          ),
        ],
      ),
    );
  }
}
