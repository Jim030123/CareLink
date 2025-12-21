import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

Future<File> downloadPdfFromFirebase(String storagePath) async {
  final ref = FirebaseStorage.instance.ref(storagePath);

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${ref.name}');

  await ref.writeToFile(file);

  return file;
}
