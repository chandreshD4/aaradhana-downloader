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
      title: 'आराधना Downloader VIP',
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

  // सभी API के लिए कॉमन सीक्रेट की (Key)
  final String _apiKey = "2a2d800e5cmsh0798dd20ef51d17p1d9715jsn2c69b2d0f7d3";

  // यूट्यूब यूआरएल से वीडियो आईडी (Video ID) निकालने का फ़ंक्शन
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

  // स्टोरेज परमिशन मांगने और फोल्डर बनाने का फ़ंक्शन
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

  // फ़ाइल को सेव करने का फ़ंक्शन
  Future<void> _saveFile(List<int> bytes, String prefix, String extension) async {
    final folder = await _prepareStorageFolder();
    if (folder == null) throw Exception("स्टोरेज परमिशन नहीं मिली!");
    
    final fileName = "${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension";
    final file = File("${folder.path}/$fileName");
    await file.writeAsBytes(bytes);
  }

  // डाउनलोड पूरा होने पर केवल एक बार ऑडियो बजाने का फ़ंक्शन
  Future<void> _playSuccessAudio() async {
    try {
      await _audioPlayer.play(AssetSource('raju_bhai.mp3'));
    } catch (e) {
      debugPrint("ऑडियो प्ले करने में एरर: $e");
    }
  }

  // मुख्य डाउनलोडर इंजन (ऑटो-स्विचिंग सिस्टम)
  Future<void> _startDownloadProcess(bool isAudio) async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _statusMessage = "❌ कृपया पहले यूट्यूब लिंक डालें!");
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.1;
      _statusMessage = "🚀 वीआईपी सर्वर से कनेक्ट हो रहा है...";
      _isSuccess = false;
    });

    final videoId = _extractVideoId(rawUrl);

    // चेन सिस्टम: एक-एक करके सभी API ट्राई करेगा
    bool success = false;

    // 1. पहली API ट्राई करें
    if (!success) success = await _tryApi1(videoId, rawUrl, isAudio);
    // 2. दूसरी API ट्राई करें
    if (!success) success = await _tryApi2(videoId, isAudio);
    // 3. तीसरी API ट्राई करें
    if (!success) success = await _tryApi3(videoId, isAudio);
    // 4. चौथी API ट्राई करें
    if (!success) success = await _tryApi4(rawUrl, isAudio);
    // 5. पांचवीं API ट्राई करें (केवल ऑडियो के लिए)
    if (!success) success = await _tryApi5(videoId, isAudio);

    setState(() {
      _isLoading = false;
      if (success) {
        _progress = 1.0;
        _isSuccess = true;
        _statusMessage = "✅ 'RajuBhai' फोल्डर में सफलतापूर्वक सेव हो गया!";
      });
      // सफलता मिलने पर आपकी वॉयस टोन बजाएं
      _playSuccessAudio();
    } else {
      setState(() {
        _progress = 0.0;
        _isSuccess = false;
        _statusMessage = "❌ डाउनलोड फेल हुआ! सभी वीआईपी लिमिट समाप्त हो चुकी हैं।";
      });
    }
  }

  // ================= API 1: youtube-media-downloader =================
  Future<bool> _tryApi1(String id, String fullUrl, bool isAudio) async {
    try {
      setState(() => _statusMessage = "⏳ सर्वर 1 से प्रयास किया जा रहा है...");
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

  // ================= API 2: youtube-video-fast-downloader-24-7 =================
  Future<bool> _tryApi2(String id, bool isAudio) async {
    try {
      setState(() => _statusMessage = "⏳ सर्वर 2 (फ़ास्ट ट्रैक) से प्रयास जारी...");
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

  // ================= API 3: youtube-mp4-mp3-downloader =================
  Future<bool> _tryApi3(String id, bool isAudio) async {
    try {
      setState(() => _statusMessage = "⏳ सर्वर 3 एक्टिवेट किया जा रहा है...");
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

  // ================= API 4: all-media-downloader4 =================
  Future<bool> _tryApi4(String fullUrl, bool isAudio) async {
    try {
      setState(() => _statusMessage = "⏳ सर्वर 4 (मीडिया हब) से कनेक्ट कर रहे हैं...");
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

  // ================= API 5: youtube-mp3-downloader5 (केवल ऑडियो के लिए) =================
  Future<bool> _tryApi5(String id, bool isAudio) async {
    if (!isAudio) return false; // यह API वीडियो सपोर्ट नहीं करती
    try {
      setState(() => _statusMessage = "⏳ सर्वर 5 (सिर्फ ऑडियो) ट्रिगर कर रहे हैं...");
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

  // बाइनरी डेटा डाउनलोड करके सेव करने का कॉमन इंजन
  Future<bool> _downloadBinary(String url, String type) async {
    try {
      setState(() {
        _progress = 0.5;
        _statusMessage = "📥 फाइल डाउनलोड हो रही है... कृपया प्रतीक्षा करें...";
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
              // ऊपर सेंटर में गोल फ्रेम में आपकी प्रोफाइल पिक्चर (profile.png)
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
                "आराधना Downloader VIP",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 40),
              // बिना किसी बॉर्डर या डिब्बे के सीधा क्लीन इनपुट फील्ड
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'यहाँ यूट्यूब लिंक पेस्ट करें...',
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
              // लाल रंग के डाउनलोड बटन
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _startDownloadProcess(true),
                icon: const Icon(Icons.music_note, color: Colors.white),
                label: const Text("🎵 Download MP3 (ऑडियो)", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
                label: const Text("🎥 Download Video (वीडियो)", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
