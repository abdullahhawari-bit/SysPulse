import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LocalServerStatus {
  final bool isRunning;
  final String? ipAddress;
  final int port;
  final String? sharedFileName;
  final int sharedFileSize;
  final int totalBytesSent;
  final int activeConnections;

  const LocalServerStatus({
    this.isRunning = false,
    this.ipAddress,
    this.port = 8080,
    this.sharedFileName,
    this.sharedFileSize = 0,
    this.totalBytesSent = 0,
    this.activeConnections = 0,
  });

  String get url => ipAddress != null ? 'http://$ipAddress:$port' : '';
}

class LocalWebServerService {
  LocalWebServerService._();
  static final LocalWebServerService instance = LocalWebServerService._();

  HttpServer? _server;
  File? _sharedFile;
  int _totalBytesSent = 0;
  int _activeConnections = 0;
  String? _localIp;
  int _port = 8080;

  final _statusController = StreamController<LocalServerStatus>.broadcast();
  Stream<LocalServerStatus> get statusStream => _statusController.stream;
  LocalServerStatus get currentStatus => LocalServerStatus(
        isRunning: _server != null,
        ipAddress: _localIp,
        port: _port,
        sharedFileName: _sharedFile != null ? _sharedFile!.uri.pathSegments.last : null,
        sharedFileSize: _sharedFile != null && _sharedFile!.existsSync() ? _sharedFile!.lengthSync() : 0,
        totalBytesSent: _totalBytesSent,
        activeConnections: _activeConnections,
      );

  Future<String?> getWifiIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<bool> startServer({File? fileToShare, int port = 8080}) async {
    await stopServer();
    _sharedFile = fileToShare;
    _totalBytesSent = 0;
    _activeConnections = 0;
    _localIp = await getWifiIp();
    _port = port;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
    } catch (_) {
      try {
        _port = 8088;
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      } catch (e) {
        return false;
      }
    }

    _server!.listen(_handleRequest);
    _notify();
    return true;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _activeConnections++;
    _notify();

    try {
      final path = request.uri.path;
      if (path == '/' || path == '/index.html') {
        await _serveWebPage(request);
      } else if (path == '/download') {
        await _serveFileDownload(request);
      } else if (path == '/api/status') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'appName': 'SysPulse',
          'device': 'Mobile Device',
          'fileName': currentStatus.sharedFileName ?? 'Vault_Archive.zip',
          'fileSize': currentStatus.sharedFileSize,
          'status': 'online',
        }));
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    } finally {
      _activeConnections = (_activeConnections - 1).clamp(0, 999);
      _notify();
    }
  }

  Future<void> _serveWebPage(HttpRequest request) async {
    final fileName = currentStatus.sharedFileName ?? 'SysPulse_Archive.zip';
    final fileSizeMb = (currentStatus.sharedFileSize / (1024 * 1024)).toStringAsFixed(1);
    final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SysPulse Local P2P Vault Transfer</title>
  <style>
    :root {
      --bg: #0B0F19;
      --card: #151D2F;
      --border: #24324D;
      --cyan: #38BDF8;
      --emerald: #10B981;
      --text: #F8FAFC;
      --sub: #94A3B8;
    }
    body {
      margin: 0;
      padding: 0;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
    }
    .container {
      max-width: 540px;
      width: 90%;
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 32px;
      box-shadow: 0 20px 40px rgba(0,0,0,0.5);
      text-align: center;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 14px;
      border-radius: 99px;
      background: rgba(16, 185, 129, 0.15);
      color: var(--emerald);
      font-size: 13px;
      font-weight: 700;
      margin-bottom: 20px;
    }
    .pulse-dot {
      width: 8px;
      height: 8px;
      background: var(--emerald);
      border-radius: 50%;
      animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
      0% { opacity: 0.4; transform: scale(0.9); }
      50% { opacity: 1; transform: scale(1.2); }
      100% { opacity: 0.4; transform: scale(0.9); }
    }
    h1 {
      margin: 0 0 8px 0;
      font-size: 26px;
      color: var(--text);
    }
    p.sub {
      color: var(--sub);
      font-size: 14px;
      margin: 0 0 28px 0;
    }
    .file-box {
      background: rgba(11, 15, 25, 0.6);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 20px;
      margin-bottom: 24px;
      text-align: left;
    }
    .file-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 10px;
      font-size: 14px;
    }
    .file-row:last-child {
      margin-bottom: 0;
    }
    .label {
      color: var(--sub);
    }
    .val {
      font-weight: 700;
      color: var(--cyan);
    }
    .btn-download {
      display: inline-block;
      width: 100%;
      box-sizing: border-box;
      background: linear-gradient(135deg, #0284C7, #0EA5E9);
      color: #FFFFFF;
      text-decoration: none;
      font-size: 16px;
      font-weight: 700;
      padding: 16px 24px;
      border-radius: 12px;
      transition: all 0.2s ease;
      box-shadow: 0 4px 14px rgba(14, 165, 233, 0.35);
    }
    .btn-download:hover {
      background: linear-gradient(135deg, #0369A1, #0284C7);
      transform: translateY(-1px);
    }
    .footer {
      margin-top: 24px;
      font-size: 12px;
      color: var(--sub);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="badge">
      <div class="pulse-dot"></div>
      P2P Local Wi-Fi Direct Active
    </div>
    <h1>SysPulse Vault Transfer</h1>
    <p class="sub">Download your archived data directly to your PC at full Wi-Fi speed (0 data consumed).</p>

    <div class="file-box">
      <div class="file-row">
        <span class="label">Archive Name:</span>
        <span class="val">$fileName</span>
      </div>
      <div class="file-row">
        <span class="label">Archive Size:</span>
        <span class="val">$fileSizeMb MB</span>
      </div>
      <div class="file-row">
        <span class="label">Transfer Protocol:</span>
        <span class="val">Local HTTP / P2P Streaming</span>
      </div>
    </div>

    <a href="/download" class="btn-download" download>
      ⚡ Download Archive to PC
    </a>

    <div class="footer">
      Powered by SysPulse Native Engine • End-to-End Local Transfer
    </div>
  </div>
</body>
</html>
''';

    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  Future<void> _serveFileDownload(HttpRequest request) async {
    if (_sharedFile == null || !_sharedFile!.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('No archive available for download.');
      await request.response.close();
      return;
    }

    final fileLength = await _sharedFile!.length();
    final fileName = _sharedFile!.uri.pathSegments.last;

    request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="$fileName"',
    );
    request.response.headers.contentType = ContentType('application', 'zip');
    request.response.headers.contentLength = fileLength;

    try {
      await request.response.addStream(
        _sharedFile!.openRead().map((chunk) {
          _totalBytesSent += chunk.length;
          _notify();
          return chunk;
        }),
      );
      await request.response.close();
    } catch (_) {}
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _totalBytesSent = 0;
      _activeConnections = 0;
      _notify();
    }
  }

  void _notify() {
    if (!_statusController.isClosed) {
      _statusController.add(currentStatus);
    }
  }

  void dispose() {
    stopServer();
    _statusController.close();
  }
}
