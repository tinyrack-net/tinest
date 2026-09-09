import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:daemon/src/features/plugins/infrastructure/plugin_network_gateway.dart';
import 'package:daemon/src/features/plugins/infrastructure/plugin_ports.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test(
    'normalizes a bounded HTTP response and preserves request options',
    () async {
      final adapter = _NetworkAdapter(
        (_, _, _) async => ResponseBody(
          Stream<List<int>>.fromIterable(<List<int>>[
            utf8.encode('one'),
            utf8.encode('two'),
          ]).map(Uint8List.fromList),
          207,
          headers: <String, List<String>>{
            'X-Test': <String>['one', 'two'],
          },
        ),
      );
      final gateway = DioPluginNetworkGateway(
        Dio()..httpClientAdapter = adapter,
      );

      final response = await gateway.send(
        _request(
          method: 'POST',
          body: utf8.encode('request'),
          headers: <String, String>{'x-input': 'value'},
        ),
        _Cancellation(),
      );

      expect(response.statusCode, 207);
      expect(utf8.decode(response.body), 'onetwo');
      expect(response.headers['x-test'], <String>['one', 'two']);
      expect(adapter.options!.method, 'POST');
      expect(adapter.options!.data, utf8.encode('request'));
      expect(adapter.options!.followRedirects, isFalse);
      expect(adapter.options!.responseType, ResponseType.stream);
    },
  );

  test('an empty request body is not sent as transport data', () async {
    final adapter = _NetworkAdapter(
      (_, _, _) async => ResponseBody.fromBytes(const <int>[], 204),
    );
    final gateway = DioPluginNetworkGateway(Dio()..httpClientAdapter = adapter);

    await gateway.send(_request(), _Cancellation());

    expect(adapter.options!.data, isNull);
  });

  test('rejects an absent response body', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<ResponseBody>(requestOptions: options, statusCode: 204),
            );
          },
        ),
      );

    expect(
      () => DioPluginNetworkGateway(dio).send(_request(), _Cancellation()),
      throwsFormatException,
    );
  });

  test(
    'rejects a streamed response once it exceeds the selected limit',
    () async {
      final adapter = _NetworkAdapter(
        (_, _, _) async => ResponseBody(
          Stream<Uint8List>.fromIterable(<Uint8List>[
            Uint8List.fromList(<int>[1, 2]),
            Uint8List.fromList(<int>[3, 4]),
          ]),
          200,
        ),
      );

      expect(
        () =>
            DioPluginNetworkGateway(Dio()..httpClientAdapter = adapter)
                .send(_request(maximumResponseBytes: 3), _Cancellation()),
        throwsFormatException,
      );
    },
  );

  test('honors cancellation before and during response streaming', () async {
    final before = _Cancellation()..cancel();
    expect(
      () => DioPluginNetworkGateway(Dio()).send(_request(), before),
      throwsA(isA<PluginHostOperationCancelledException>()),
    );

    final during = _Cancellation();
    final adapter = _NetworkAdapter(
      (_, _, _) async => ResponseBody(
        (() async* {
          yield Uint8List.fromList(<int>[1]);
          during.markCancelledWithoutCallback();
          yield Uint8List.fromList(<int>[2]);
        })(),
        200,
      ),
    );
    expect(
      () =>
          DioPluginNetworkGateway(Dio()..httpClientAdapter = adapter)
              .send(_request(), during),
      throwsA(isA<PluginHostOperationCancelledException>()),
    );
  });

  test('classifies invocation cancellation separately from deadline', () async {
    final invocation = _Cancellation();
    final cancellingAdapter = _NetworkAdapter((
      options,
      stream,
      cancelFuture,
    ) async {
      await cancelFuture;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    });
    final invocationFuture = DioPluginNetworkGateway(
      Dio()..httpClientAdapter = cancellingAdapter,
    ).send(_request(), invocation);
    invocation.cancel();
    await expectLater(
      invocationFuture,
      throwsA(isA<PluginHostOperationCancelledException>()),
    );

    final deadlineAdapter = _NetworkAdapter((
      options,
      stream,
      cancelFuture,
    ) async {
      await cancelFuture;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    });
    await expectLater(
      DioPluginNetworkGateway(Dio()..httpClientAdapter = deadlineAdapter).send(
        _request(timeout: const Duration(milliseconds: 1)),
        _Cancellation(),
      ),
      throwsA(
        isA<PluginNetworkTransportException>().having(
          (failure) => failure.kind,
          'kind',
          'deadline',
        ),
      ),
    );
  });

  test('redacts transport failures to their stable Dio kind', () async {
    final adapter = _NetworkAdapter((options, stream, cancelFuture) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: StateError('secret endpoint failed'),
      );
    });

    final future = DioPluginNetworkGateway(Dio()..httpClientAdapter = adapter)
        .send(_request(), _Cancellation());
    await expectLater(
      future,
      throwsA(
        isA<PluginNetworkTransportException>()
            .having((failure) => failure.kind, 'kind', 'connectionError')
            .having(
              (failure) => failure.toString(),
              'message',
              'Plugin network request failed: connectionError',
            ),
      ),
    );
  });
}

PluginNetworkRequest _request({
  String method = 'GET',
  Map<String, String> headers = const <String, String>{},
  List<int> body = const <int>[],
  Duration timeout = const Duration(seconds: 1),
  int maximumResponseBytes = 1024,
}) => PluginNetworkRequest(
  uri: Uri.parse('https://plugin.example/resource'),
  method: method,
  headers: headers,
  body: body,
  timeout: timeout,
  maximumResponseBytes: maximumResponseBytes,
);

final class _NetworkAdapter implements HttpClientAdapter {
  new(this._fetch);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  )
  _fetch;

  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    this.options = options;
    return _fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

final class _Cancellation implements PluginOperationCancellation {
  bool _cancelled = false;
  final List<void Function()> _callbacks = <void Function()>[];

  @override
  bool get isCancelled => _cancelled;

  @override
  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final callback in List<void Function()>.of(_callbacks)) {
      callback();
    }
    _callbacks.clear();
  }

  void markCancelledWithoutCallback() {
    _cancelled = true;
  }
}
