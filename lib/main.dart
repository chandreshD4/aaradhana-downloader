import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const MaterialApp(
    home: RajuBhaiDownloader(),
    debugShowCheckedModeBanner: false,
  ));
}

class RajuBhaiDownloader extends StatefulWidget {
  const RajuBhaiDownloader({Key? key}) : super(key: key);

  @override
  State<RajuBhaiDownloader> createState() => _RajuBhaiDownloaderState();
}

class _RajuBhaiDownloaderState extends State<RajuBhaiDownloader> {
  final TextEditingController _urlController = TextEditingController();
  final Dio _dio = Dio();
  
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = "यहाँ यूट्यूब वीडियो का लिंक डालें...";
  
  // रैपिड एपीआई क्रेडेंशियल्स
  final String _apiKey = "2a2d800e5cmsh0798dd20ef51d17p1d9715jsn2c69b2d0f7d3";
  final String _apiHost = "youtube-media-downloader.p.rapidapi.com";

  String? _extractVideoId(String url) {
    RegExp regExp = RegExp(r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*');
    Match? match = regExp.firstMatch(url);
    return (match != null && match.group(2)!.length == 11) ? match.group(2) : null;
  }

  Future<void> _startDownload(String type) async {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _statusText = "❌ कृपया पहले लिंक डालें!");
      return;
    }

    String? videoId = _extractVideoId(url);
    if (videoId == null) {
      setState(() => _statusText = "❌ अमान्य यूट्यूब लिंक!");
      return;
    }

    // स्टोरेज परमिशन मांगना
    var status = await Permission.storage.request();
    var extStatus = await Permission.manageExternalStorage.request();
    
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = "⏳ लिंक से फाइल खोजी जा रही है...";
    });

    try {
      // एपीआई से डायरेक्ट डाउनलोड लिंक फेच करना
      Response response = await _dio.get(
        "https://$_apiHost/v2/video/details?videoId=$videoId",
        options: Options(headers: {
          "x-rapidapi-key": _apiKey,
          "x-rapidapi-host": _apiHost,
        }),
      );

      var data = response.data;
      String? downloadUrl;

      if (type == 'mp3' && data['audios']?['items'] != null && data['audios']['items'].isNotEmpty) {
        downloadUrl = data['audios']['items'][0]['url'];
      } else if (data['videos']?['items'] != null && data['videos']['items'].isNotEmpty) {
        downloadUrl = data['videos']['items'][0]['url'];
      } else {
        downloadUrl = data['download_url'] ?? data['link'] ?? data['url'];
      }

      if (downloadUrl == null) throw Exception("डाउनलोड लिंक नहीं मिला।");

      // मुख्य स्टोरेज में 'RajuBhai' फोल्डर का पाथ सेट करना
      String timeStamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      String ext = (type == 'mp3') ? 'mp3' : 'mp4';
      String savePath = "/sdcard/RajuBhai/RajuBhai_${type.toUpperCase()}_$timeStamp.$ext";

      // बिना प्लेयर खोले सीधे फोल्डर में लाइव प्रोग्रेस के साथ डाउनलोड करना
      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _statusText = "📥 सीधे राजू भाई फोल्डर में सेव हो रहा है: ${(_progress * 100).toStringAsFixed(0)}%";
            });
          }
        },
      );

      setState(() {
        _statusText = "✅ 'RajuBhai' फोल्डर में सफलतापूर्वक सेव हो गया!";
        _progress = 1.0;
      });

    } catch (e) {
      setState(() {
        _statusText = "❌ डाउनलोड फेल हुआ! कृपया पुनः प्रयास करें।";
        _progress = 0.0;
      });
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "🚀 आराधना Downloader VIP",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "यहाँ यूट्यूब वीडियो का लिंक डालें...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF334155), width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      minimumSize: const Size.fromHeight(55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isDownloading ? null : () => _startDownload('mp3'),
                    icon: const Icon(Icons.music_note, color: Colors.white),
                    label: const Text("🎵 Download MP3 (ऑडियो)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      minimumSize: const Size.fromHeight(55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isDownloading ? null : () => _startDownload('mp4'),
                    icon: const Icon(Icons.video_library, color: Colors.white),
                    label: const Text("🎥 Download Video (वीडियो)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (_isDownloading || _progress > 0) ...[
                    const SizedBox(height: 25),
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: const Color(0xFF334155),
                      color: const Color(0xFF38EF7D),
                      minHeight: 10,
                    ),
                  ],
                  const SizedBox(height: 15),
                  Text(
                    _statusText,
                    textAlign: Center,
                    style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
