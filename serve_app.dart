import 'dart:io';

void main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('Listening on http://${server.address.address}:${server.port}');

  await for (HttpRequest request in server) {
    if (request.method == 'GET') {
      final path = request.uri.path == '/' ? 'index.html' : request.uri.path.substring(1);
      final file = File('build/web/$path');
      if (await file.exists()) {
        request.response.headers.contentType = _getContentType(path);
        await file.openRead().pipe(request.response);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      }
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.close();
    }
  }
}

ContentType _getContentType(String path) {
  if (path.endsWith('.html')) return ContentType.html;
  if (path.endsWith('.js')) return ContentType('application', 'javascript');
  if (path.endsWith('.css')) return ContentType('text', 'css');
  if (path.endsWith('.png')) return ContentType('image', 'png');
  return ContentType.binary;
}
