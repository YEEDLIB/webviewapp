import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local WebView App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    // Copy assets to local storage
    await _copyAssetsToAppDirectory();

    // Get the path to the main HTML file
    final appDir = await getApplicationDocumentsDirectory();
    final htmlPath = '${appDir.path}/html/index.html';

    // Initialize WebView controller
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.white);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          setState(() {
            _progress = progress / 100;
          });
        },
        onPageStarted: (String url) {
          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (String url) {
          setState(() {
            _isLoading = false;
          });
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
        },
      ),
    );

    // Load the local HTML file
    await controller.loadFile(htmlPath);

    _webViewController = controller;
    setState(() {});
  }

  Future<void> _copyAssetsToAppDirectory() async {
    // Create directories if they don't exist
    final appDir = await getApplicationDocumentsDirectory();
    final htmlDir = Directory('${appDir.path}/html');
    final cssDir = Directory('${appDir.path}/css');
    final jsDir = Directory('${appDir.path}/js');

    if (!await htmlDir.exists()) await htmlDir.create(recursive: true);
    if (!await cssDir.exists()) await cssDir.create(recursive: true);
    if (!await jsDir.exists()) await jsDir.create(recursive: true);

    // Copy HTML files
    try {
      final htmlFiles = ['index.html', 'about.html'];
      for (var file in htmlFiles) {
        final data = await rootBundle.load('assets/html/$file');
        final bytes = data.buffer.asUint8List();
        await File('${htmlDir.path}/$file').writeAsBytes(bytes);
      }
    } catch (e) {
      debugPrint('Error copying HTML files: $e');
    }

    // Copy CSS files
    try {
      final cssFiles = ['style.css'];
      for (var file in cssFiles) {
        final data = await rootBundle.load('assets/css/$file');
        final bytes = data.buffer.asUint8List();
        await File('${cssDir.path}/$file').writeAsBytes(bytes);
      }
    } catch (e) {
      debugPrint('Error copying CSS files: $e');
    }

    // Copy JS files
    try {
      final jsFiles = ['script.js'];
      for (var file in jsFiles) {
        final data = await rootBundle.load('assets/js/$file');
        final bytes = data.buffer.asUint8List();
        await File('${jsDir.path}/$file').writeAsBytes(bytes);
      }
    } catch (e) {
      debugPrint('Error copying JS files: $e');
    }
  }

  Future<void> _loadPage(String pageName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final htmlPath = '${appDir.path}/html/$pageName.html';
    await _webViewController.loadFile(htmlPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local WebView App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => _loadPage('index'),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Local WebView App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Load local HTML/CSS/JS files',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home Page'),
              onTap: () {
                Navigator.pop(context);
                _loadPage('index');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About Page'),
              onTap: () {
                Navigator.pop(context);
                _loadPage('about');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Run JavaScript'),
              onTap: () async {
                Navigator.pop(context);
                await _webViewController.runJavaScript(
                  'document.body.innerHTML += "<p style=\'color: green; padding: 10px; background: #f0f0f0; margin: 10px;\'>JavaScript executed from Flutter!</p>";',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text('Go Back'),
              onTap: () async {
                Navigator.pop(context);
                if (await _webViewController.canGoBack()) {
                  await _webViewController.goBack();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward),
              title: const Text('Go Forward'),
              onTap: () async {
                Navigator.pop(context);
                if (await _webViewController.canGoForward()) {
                  await _webViewController.goForward();
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            ),
          Expanded(
            child: WebViewWidget(controller: _webViewController),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Execute JavaScript from Flutter
          await _webViewController.runJavaScript(
            'showMessage("Hello from Flutter!");',
          );
        },
        child: const Icon(Icons.message),
      ),
    );
  }
}
