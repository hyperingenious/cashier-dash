import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeClient {
  RealtimeClient({
    required String url,
    required String? Function() tokenProvider,
  })  : _url = url,
        _tokenProvider = tokenProvider;

  final String _url;
  final String? Function() _tokenProvider;
  final StreamController<Map<String, dynamic>> _events = StreamController.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;
  int _attempt = 0;

  Stream<Map<String, dynamic>> get events => _events.stream;

  void connect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _open();
  }

  void _open() {
    final token = _tokenProvider();
    final uri = Uri.parse(_url);
    final params = Map<String, String>.from(uri.queryParameters);
    if (token != null && token.isNotEmpty) {
      params['token'] = token;
    }
    final withToken = uri.replace(queryParameters: params.isEmpty ? null : params);

    print('[RealtimeClient] Connecting to $withToken ...');
    _channel = WebSocketChannel.connect(withToken);

    // Reset attempt counter on successful open
    _attempt = 0;

    _subscription = _channel!.stream.listen(
      (message) {
        if (message is String) {
          try {
            final data = jsonDecode(message);
            if (data is Map<String, dynamic>) {
              final type = data['type'];
              print('[RealtimeClient] ⬇️  Received event: $type');
              _events.add(data);
            }
          } catch (_) {
            // Ignore non-JSON payloads.
          }
        }
      },
      onError: (e) {
        print('[RealtimeClient] ❌ Error: $e');
        _scheduleReconnect();
      },
      onDone: () {
        print('[RealtimeClient] 🔌 Connection closed');
        _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _subscription?.cancel();
    _channel = null;
    _attempt = (_attempt + 1).clamp(1, 6);
    final delay = Duration(seconds: 1 << (_attempt - 1));
    print('[RealtimeClient] ♻️  Reconnecting in ${delay.inSeconds}s (attempt $_attempt)');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _open);
  }

  void close() {
    _closed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    print('[RealtimeClient] Closed');
  }
}

