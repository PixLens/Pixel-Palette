import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' as pkg_ffi;
import 'package:path_provider/path_provider.dart';

/// `~/Documents/<folderName>` 디렉터리를 반환한다. 없으면 생성한다.
///
/// macOS 앱 샌드박스 안에서는 `HOME` 환경변수가 컨테이너 경로
/// (`~/Library/Containers/<bundle-id>/Data`)를 가리켜 실제 `~/Documents`와
/// 달라지므로, `getpwuid(getuid())`(POSIX API)로 실제 사용자 홈 디렉터리를 얻는다.
///
/// [override]가 주어지면 (테스트용) 그 경로를 그대로 사용한다.
Future<Directory> documentsSubDir(String folderName, {String? override}) async {
  final base = override != null
      ? Directory(override)
      : Platform.isMacOS && realHomeDir() != null
          ? Directory('${realHomeDir()}/Documents/$folderName')
          : Directory(
              '${(await getApplicationDocumentsDirectory()).path}/$folderName');
  if (!await base.exists()) await base.create(recursive: true);
  return base;
}

final class _Passwd extends ffi.Struct {
  external ffi.Pointer<pkg_ffi.Utf8> pwName;
  external ffi.Pointer<pkg_ffi.Utf8> pwPasswd;
  @ffi.Uint32()
  external int pwUid;
  @ffi.Uint32()
  external int pwGid;
  @ffi.Int64()
  external int pwChange;
  external ffi.Pointer<pkg_ffi.Utf8> pwClass;
  external ffi.Pointer<pkg_ffi.Utf8> pwGecos;
  external ffi.Pointer<pkg_ffi.Utf8> pwDir;
  external ffi.Pointer<pkg_ffi.Utf8> pwShell;
  @ffi.Int64()
  external int pwExpire;
}

/// `getpwuid(getuid())`로 실제 사용자 홈 디렉터리(예: `/Users/sjy`)를 가져온다.
/// 샌드박스 컨테이너로 리다이렉트되는 `HOME` 환경변수와 달리, 시스템의
/// 사용자 계정 정보(Open Directory)를 직접 조회하므로 실제 경로를 반환한다.
String? realHomeDir() {
  try {
    final lib = ffi.DynamicLibrary.process();
    final getuid =
        lib.lookupFunction<ffi.Uint32 Function(), int Function()>('getuid');
    final getpwuid = lib.lookupFunction<
        ffi.Pointer<_Passwd> Function(ffi.Uint32),
        ffi.Pointer<_Passwd> Function(int)>('getpwuid');
    final passwd = getpwuid(getuid());
    if (passwd == ffi.nullptr) return null;
    return passwd.ref.pwDir.toDartString();
  } catch (_) {
    return null;
  }
}
