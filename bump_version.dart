import 'dart:io';

void main() {
  final file = File('pubspec.yaml');
  final lines = file.readAsLinesSync();

  final versionIndex = lines.indexWhere((line) => line.startsWith('version:'));
  if (versionIndex == -1) {
    print('Version satırı bulunamadı!');
    exit(1);
  }

  final versionLine = lines[versionIndex];
  final regex = RegExp(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)');
  final match = regex.firstMatch(versionLine);

  if (match == null) {
    print('Versiyon formatı geçersiz!');
    exit(1);
  }

  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  final patch = int.parse(match.group(3)!);
  final build = int.parse(match.group(4)!);

  final newBuild = build + 1;
  final newVersionLine = 'version: $major.$minor.$patch+$newBuild';

  lines[versionIndex] = newVersionLine;
  file.writeAsStringSync(lines.join('\n'));

  print('✔ Versiyon güncellendi: $newVersionLine');

}
