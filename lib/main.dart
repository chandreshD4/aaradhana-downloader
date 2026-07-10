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
      _progress = 0.1;
      _statusMessage = "🚀 વીઆઈપી સર્વર સાથે કનેક્ટ થઈ રહ્યું છે...";
      _isSuccess = false;
    });

    final videoId = _extractVideoId(rawUrl);
    bool success = false;

    if (!success) success = await _tryApi1(videoId, rawUrl, isAudio);
    if (!success) success = await _tryApi2(videoId, isAudio);
    if (!success) success = await _tryApi3(videoId, isAudio);
    if (!success) success = await _tryApi4(rawUrl, isAudio);
    if (!success) success = await _tryApi5(videoId, isAudio);

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
        _statusMessage = "❌ ડાઉનલોડ ફેલ થયું! બધી વીઆઈપી લિમિટ સમાપ્ત થઈ ગઈ છે.";
      }
    });
  }

  Future<bool> _tryApi1(String id, String fullUrl, bool isAudio) async {
    try {
      setState(() => _statusMessage = "⏳ સર્વર 1 થી પ્રયાસ કરવામાં આવી રહ્યો છે...");
      final response = await http.get(
        Uri.parse("https://youtube-media-downloader.p.rapidapi.com/v2/video/details?videoId=$id"),
        headers: {"x-rapidapi-key": _apiKey, "x-rapidapi-host": "youtube-media-downloader.p.rapidapi.com"},
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      String? dlUrl;
      if (isAudio) {
        final audios = data['audios']?['items'] as List?;
        if (audios != null && audios.isNotEmpty) dlUrl = audios.first['url'];
      } else {
        final videos = data['videos']?['items'] as List?;
        if (videos != null && videos.isNotEmpty) dlUrl = videos.first['url'];
      }
      if (dlUrl == null) return false;
      return await _downloadBinary(dlUrl, isAudio ? "MP3" : "MP4");
    } catch (_) { return false; }
  }

  Future<bool> _tryApi2(String id, bool isAudio) async {
    try {
      setState(() => _statusMessage = "⏳ સર્વर 2 થી પ્રયાસ ચાલુ છે...");
      String endpoint = isAudio 
        ? "https://youtube-video-fast-downloader-24-7.p.rapidapi.com/download_audio/$id?quality=251"
        : "https://youtube-video-fast-downloader-24-7.p.rapidapi.com/download_video/$id?quality=22";
      
      final response = await http.get(Uri.parse(endpoint), headers: {
        "x-rapidapi-key": _apiKey,
        "x-rapidapi-host": "youtube-video-fast-downloader-24-7.p.rapidapi.com"
      });
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      String? dlUrl = data['link'] ?? data['url'];
      if (dlUrl == null) return false;
      return await _downloadBinary(dlUrl, isAudio ? "MP3" : "MP4");
    } catch (_) { return false; }
  }

  Future<bool> _tryApi3(String id, bool isAudio) async {
    try {
      setState(() => _statusMessage = "⏳ સર્વર 3 એક્ટિવેટ કરવામાં આવી રહ્યું છે...");
      String format = isAudio ? "128" : "720";
      final response = await http.get(
        Uri.parse("https://youtube-mp4-mp3-downloader.p.rapidapi.com/api/v1/download?format=$format&id=$id&audioQuality=128"),
        headers: {"x-rapidapi-key": _apiKey, "x-rapidapi-host": "youtube-mp4-mp3-downloader.p.rapidapi.com"},
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      String? dlUrl = data['link'] ?? data['url'] ?? data['download_url'];
      if (dlUrl == null) return false;
      return await _downloadBinary(dlUrl, isAudio ? "MP3" : "MP4");
    } catch (_) { return false; }
  }

  Future<bool> _tryApi4(String fullUrl, bool isAudio) async {
    try {
      setState(() => _statusMessage = "⏳ સર્વર 4 થી કનેક્ટ થઈ રહ્યું છે...");
      final response = await http.get(
        Uri.parse("https://all-media-downloader4.p.rapidapi.com/api/youtube/download?id=${Uri.encodeComponent(fullUrl)}"),
        headers: {"x-rapidapi-key": _apiKey, "x-rapidapi-host": "all-media-downloader4.p.rapidapi.com"},
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
      return await _downloadBinary(dlUrl, isAudio ? "MP3" : "MP4");
    } catch (_) { return false; }
  }

  Future<bool> _tryApi5(String id, bool isAudio) async {
    if (!isAudio) return false;
    try {
      setState(() => _statusMessage = "⏳ સર્વર 5 (ફક્ત ઓડિયો) ટ્રિગર થઈ રહ્યું છે...");
      final response = await http.get(
        Uri.parse("https://youtube-mp3-downloader5.p.rapidapi.com/?youtube_url=https://www.youtube.com/watch?v=$id"),
        headers: {"x-rapidapi-key": _apiKey, "x-rapidapi-host": "youtube-mp3-downloader5.p.rapidapi.com"},
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      String? dlUrl = data['link'] ?? data['url'];
      if (dlUrl == null) return false;
      return await _downloadBinary(dlUrl, "MP3");
    } catch (_) { return false; }
  }

  Future<bool> _downloadBinary(String url, String type) async {
    try {
      setState(() {
        _progress = 0.5;
        _statusMessage = "📥 ફાઇલ ડાઉનલોડ થઈ રહી છે... કૃપા કરીને પ્રતીક્ષા કરો...";
      });
      final fileRes = await http.get(Uri.parse(url));
      if (fileRes.statusCode == 200) {
        await _saveFile(fileRes.bodyBytes, "RajuBhai", type.toLowerCase());
        return true;
      }
      return false;
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
                      backgroundColor: Colors.black10,
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
