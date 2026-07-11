import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const AaradhanaDownloaderApp());
}

class AaradhanaDownloaderApp extends StatelessWidget {
  const AaradhanaDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'આરાધના Downloader VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.red,
      ),
      home: const DownloadScreen(),
    );
  }
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = false;
  double _progress = 0.0;
  String _statusMessage = "";
  bool _isSuccess = false;

  final String _apiKey = "2a2d800e5cmsh0798dd20ef51d17p1d9715jsn2c69b2d0f7d3";
  final String _apiHost = "all-media-downloader4.p.rapidapi.com";

  String _extractVideoId(String url) {
    if (url.contains("youtu.be/")) {
      return url.split("youtu.be/")[1].split("?")[0].trim();
    } else if (url.contains("v=")) {
      return url.split("v=")[1].split("&")[0].trim();
    } else if (url.contains("embed/")) {
      return url.split("embed/")[1].split("?")[0].trim();
    }
    return url.trim();
  }

  Future<Directory?> _prepareStorageFolder() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted) {
        final dir = Directory('/storage/emulated/0/RajuBhai');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }
    return null;
  }

  Future<void> _saveFile(List<int> bytes, String prefix, String extension) async {
    final folder = await _prepareStorageFolder();
    if (folder == null) throw Exception("સ્ટોરેજ પરમિશન નથી મળી!");
    
    final fileName = "${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension";
    final file = File("${folder.path}/$fileName");
    await file.writeAsBytes(bytes);
  }

  Future<void> _playSuccessAudio() async {
    try {
      await _audioPlayer.play(AssetSource('raju_bhai.mp3'));
    } catch (e) {
      debugPrint("ઓડિયો પ્લે કરવામાં એરર: $e");
    }
  }

  Future<void> _startDownloadProcess(bool isAudio) async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _statusMessage = "❌ કૃપા કરીને પહેલા યુટ્યુબ લિંક નાખો!");
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _statusMessage = "🚀 વીઆઈપી સર્વર સાથે કનેક્ટ થઈ રહ્યું છે...";
      _isSuccess = false;
    });

    final videoId = _extractVideoId(rawUrl);
    bool success = await _tryAllMediaDownloader(videoId, isAudio);

    setState(() {
      _isLoading = false;
      if (success) {
        _progress = 1.0;
        _isSuccess = true;
        _statusMessage = "✅ 'RajuBhai' ફોલ્ડરમાં સફળતાપૂર્વક સેવ થઈ ગયું!";
        _playSuccessAudio();
      } else {
        _progress = 0.0;
        _isSuccess = false;
        _statusMessage = "❌ ડાઉનલોડ ફેલ થયું! વીઆઈપી લિમિટ તપાસો અથવા ફરી પ્રયાસ કરો.";
      }
    });
  }

  Future<bool> _tryAllMediaDownloader(String id, bool isAudio) async {
    try {
      setState(() => _statusMessage = "⏳ વીઆઈપી ઓલ મીડિયા સર્વર થી પ્રયાસ ચાલુ છે...");
      
      final response = await http.get(
        Uri.parse("https://$_apiHost/api/youtube/download?id=$id"),
        headers: {
          "Content-Type": "application/json",
          "x-rapidapi-key": _apiKey,
          "x-rapidapi-host": _apiHost
        },
      );
      
      if (response.statusCode != 200) return false;
      
      final data = jsonDecode(response.body);
      String? dlUrl;
      
      if (isAudio) {
        dlUrl = data['audio'] ?? data['formats']?[0]?['url'];
      } else {
        dlUrl = data['video'] ?? data['formats']?[1]?['url'] ?? data['formats']?[0]?['url'];
      }
      
      if (dlUrl == null) return false;
      return await _downloadBinaryWithProgress(dlUrl, isAudio ? "MP3" : "MP4");
    } catch (_) { 
      return false; 
    }
  }

  Future<bool> _downloadBinaryWithProgress(String url, String type) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) return false;

      final totalBytes = response.contentLength ?? 0;
      List<int> bytes = [];
      num lastProgress = -1;

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        if (totalBytes > 0) {
          double currentProgress = bytes.length / totalBytes;
          int percent = (currentProgress * 100).toInt();
          if (percent != lastProgress) {
            lastProgress = percent;
            setState(() {
              _progress = currentProgress;
              _statusMessage = "📥 ડાઉનલોડ થઈ રહ્યું છે: $percent%";
            });
          }
        } else {
          setState(() {
            _progress = 0.5;
            _statusMessage = "📥 ફાઇલ આવી રહી છે... કૃપા કરીને પ્રતીક્ષા કરો...";
          });
        }
      }

      await _saveFile(bytes, "RajuBhai", type.toLowerCase());
      return true;
    } catch (_) { return false; }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: AssetImage('assets/profile.png'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "આરાધના Downloader VIP",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'અહીં યુટ્યુબ લિંક પેસ્ટ કરો...',
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _startDownloadProcess(true),
                icon: const Icon(Icons.music_note, color: Colors.white),
                label: const Text("🎵 Download MP3 (ઓડિયો)", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _startDownloadProcess(false),
                icon: const Icon(Icons.movie, color: Colors.white),
                label: const Text("🎥 Download Video (વિડિયો)", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
              if (_isLoading || _statusMessage.isNotEmpty) ...[
                const SizedBox(height: 30),
                if (_isLoading)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                      minHeight: 6,
                    ),
                  ),
                const SizedBox(height: 15),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isSuccess ? Colors.green : (_statusMessage.startsWith("❌") ? Colors.redAccent : Colors.black54),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
