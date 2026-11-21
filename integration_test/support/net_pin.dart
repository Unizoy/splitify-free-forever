import 'dart:io';

/// Dev-network workaround (S-214): on this PC's ISP every plain DNS answer for `*.supabase.co` is a block-page
/// address, and the emulator can only use plain DNS. With `--dart-define=PIN_HOST_IP=<address>` (resolved on the
/// PC, which uses DNS over HTTPS) the tests connect to that address with the right TLS server name, so
/// certificates are still checked. No effect when the define is empty.
void pinHost(String host) {
  const ip = String.fromEnvironment('PIN_HOST_IP');
  if (ip.isEmpty) return;
  HttpOverrides.global = _PinnedHost(host, InternetAddress(ip));
}

class _PinnedHost extends HttpOverrides {
  _PinnedHost(this.host, this.address);

  final String host;
  final InternetAddress address;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final secure = uri.scheme == 'https' || uri.scheme == 'wss';
      if (uri.host != host) {
        return secure
            ? SecureSocket.startConnect(uri.host, uri.port, context: context)
            : Socket.startConnect(uri.host, uri.port);
      }
      final task = await Socket.startConnect(address, uri.port);
      return ConnectionTask.fromSocket(
        secure
            ? task.socket.then((s) => SecureSocket.secure(s, host: host, context: context))
            : task.socket,
        task.cancel,
      );
    };
    return client;
  }
}
