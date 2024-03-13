import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_svprogresshud/flutter_svprogresshud.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;


class DetailPage extends StatefulWidget {
  final BluetoothDevice server;
  final String? ipAddress;

  const DetailPage({Key? key, required this.server, this.ipAddress}) : super(key: key);

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  BluetoothConnection? connection;
  bool isConnecting = true;
  bool get isConnected => connection != null && connection!.isConnected;
  bool isDisconnecting = false;

  late String _selectedFrameSize;
  List<List<int>> chunks = <List<int>>[];
  int contentLength = 0;
  Uint8List? _bytes;
  RestartableTimer? _timer;
  String? _imageCaption;

  final FlutterTts flutterTts = FlutterTts();

  stt.SpeechToText? _speech;
  bool _isListening = false;
  String _text = '';
  Timer? _timerr;
  final int _restartInterval = 4;

  @override
  void initState() {
    super.initState();
    _selectedFrameSize = '0';
    _getBTConnection();
    _timer = RestartableTimer(const Duration(seconds: 1), _drawImage);
    _initSpeechToText();
  }

  @override
  void dispose() {
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }
    _timer?.cancel();
    _speech?.stop();
    _timerr?.cancel();
    super.dispose();
  }

  _getBTConnection() {
    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      connection = _connection;
      isConnecting = false;
      isDisconnecting = false;
      setState(() {});
      connection?.input?.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally');
        } else {
          print('Disconnecting remotely');
        }
        if (this.mounted) {
          setState(() {});
        }
        Navigator.of(context).pop();
      });
    }).catchError((error) {
      Navigator.of(context).pop();
    });
  }

  _drawImage() async {
    if (chunks.isEmpty || contentLength == 0) return;

    _bytes = Uint8List(contentLength);
    int offset = 0;
    for (final List<int> chunk in chunks) {
      _bytes?.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    setState(() {});

    SVProgressHUD.showInfo(status: "Downloaded...");
    SVProgressHUD.dismiss(delay: const Duration(milliseconds: 1000));

    final directory = await getExternalStorageDirectory();
    final file = File('${directory?.path}/image.jpeg');
    await file.writeAsBytes(_bytes as List<int>);

    print("Image saved at: ${directory?.path}");

    _captionImage(file);

    contentLength = 0;
    chunks.clear();
  }

  void _onDataReceived(Uint8List data) async {
    if (data.isNotEmpty) {
      chunks.add(data);
      contentLength += data.length;
      _timer?.reset();
    }

    if (contentLength > 0) {
      // Store the received image data in a file
      // File imageFile = await _saveImageToFile(data);

      // Caption the received image
      // _captionImage(imageFile);
    }

    if (kDebugMode) {
      print("Data Length: ${data.length}, chunks: ${chunks.length}");
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    if (text.isNotEmpty) {
      try {
        List<int> list = text.codeUnits;
        Uint8List bytes = Uint8List.fromList(list);
        connection?.output.add(bytes);
        SVProgressHUD.show(status: "Requesting...");
        await connection?.output.allSent;
      } catch (e) {
        setState(() {});
      }
    }
  }

  Future<http.Response> sendImageToServer(File imageFile) async {
    var url = Uri.parse('http://${widget.ipAddress}:8000/image-captioning/');
    var request = http.MultipartRequest('POST', url);
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    var streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  Future<void> _captionImage(File imageFile) async {
    try {
      var response = await sendImageToServer(imageFile);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final sentence = responseBody['image'];
        setState(() {
          _imageCaption = sentence;
        });
        await _speakCaption(_imageCaption!);
        _startListening();
      } else {
        if (kDebugMode) {
          print('Failed to caption image. Error: ${response.reasonPhrase}');
        }
      }
    } catch (e) {
      print('Error captioning image: $e');
    }
  }

  Future<void> _speakCaption(String caption) async {
    await flutterTts.setLanguage('en-US');
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak(caption);
  }

  Future<void> _initSpeechToText() async {
    _speech = stt.SpeechToText();
    await _speech!.initialize(
      onStatus: (status) {
        print('Speech recognition status: $status');
      },
      onError: (error) {
        print('Speech recognition error: $error');
      },
    );
    if (_speech!.isAvailable) {
      _startListening();
    } else {
      print('Speech recognition not available');
    }
  }

  void _startListening() {
    _speech!.listen(
      onResult: (result) {
        setState(() {
          _text = result.recognizedWords ?? '';
          print('Recognized text: $_text');
          if (_text.toLowerCase().contains('capture')) {
            _speech?.stop();
            _sendMessage(_selectedFrameSize);
          } else {
            _startListening();
          }
        });
      },
    );
    _isListening = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: (isConnecting
            ? Text('Connecting to ${widget.server.name} ...')
            : isConnected
            ? Text('Connected with ${widget.server.name}')
            : Text('Disconnected with ${widget.server.name}')),
      ),
      body: SafeArea(
        child: isConnected
            ? Column(
          children: <Widget>[
            selectFrameSize(),
            captionword(),
            photoFrame(),
          ],
        )
            : const Center(
          child: Text(
            "Connecting...",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget photoFrame() {
    return Expanded(
      child: Container(
        width: double.infinity,
        child: _bytes != null
            ? PhotoView(
          enableRotation: true,
          initialScale: PhotoViewComputedScale.covered,
          maxScale: PhotoViewComputedScale.covered * 2.0,
          minScale: PhotoViewComputedScale.contained * 0.8,
          imageProvider: Image.memory(_bytes!, fit: BoxFit.fitWidth).image,
        )
            : Container(),
      ),
    );
  }

  Widget captionword() {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Voice recognition:'),
          Text(_text),
        ],
      ),
    );
  }

  Widget selectFrameSize() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'FRAME SIZE',
          border: OutlineInputBorder(),
        ),
        value: _selectedFrameSize,
        onChanged: (String? value) {
          if (value != null) {
            setState(() {
              _selectedFrameSize = value;
            });
          }
        },
        items: const [
          DropdownMenuItem<String>(
            value: "4",
            child: Text("1600x1200"),
          ),
          DropdownMenuItem<String>(
            value: "3",
            child: Text("1280x1024"),
          ),
          DropdownMenuItem<String>(
            value: "2",
            child: Text("1024x768"),
          ),
          DropdownMenuItem<String>(
            value: "1",
            child: Text("800x600"),
          ),
          DropdownMenuItem<String>(
            value: "0",
            child: Text("640x480"),
          ),
        ],
      ),
    );
  }
}
