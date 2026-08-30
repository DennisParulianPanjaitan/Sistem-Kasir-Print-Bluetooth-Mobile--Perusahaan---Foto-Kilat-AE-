import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Utility untuk mengkonversi gambar PNG menjadi perintah ESC/POS
/// yang bisa dipahami oleh printer thermal 58mm.
class EscPosImageConverter {
  /// Mengkonversi file PNG menjadi byte array ESC/POS yang siap dikirim ke printer.
  /// Printer thermal 58mm = 384 pixel lebar area cetak.
  static Future<List<int>> convertImageToEscPos(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) throw Exception('Gagal membaca gambar');

    // Resize ke lebar 384px (standar 58mm printer thermal)
    final resized = img.copyResize(originalImage, width: 384);

    // Konversi ke grayscale lalu ke monochrome (hitam putih murni)
    final grayscale = img.grayscale(resized);

    final int widthInBytes = (grayscale.width + 7) ~/ 8; // pembulatan ke atas
    final int height = grayscale.height;

    List<int> escPosBytes = [];

    // Reset printer
    escPosBytes.addAll([0x1B, 0x40]); // ESC @

    // Set line spacing ke 0 agar tidak ada gap antar baris gambar
    escPosBytes.addAll([0x1B, 0x33, 0x00]); // ESC 3 0

    // Cetak gambar per baris menggunakan ESC * (bit image mode)
    // Mode 33 = 24-dot double-density
    // Kita proses per 24 baris sekaligus
    for (int y = 0; y < height; y += 24) {
      // ESC * m nL nH
      escPosBytes.addAll([0x1B, 0x2A, 33]); // ESC * mode=33
      // nL nH = width in dots (low byte, high byte)
      escPosBytes.add(grayscale.width & 0xFF); // nL
      escPosBytes.add((grayscale.width >> 8) & 0xFF); // nH

      // Data: untuk setiap kolom x, kirim 3 bytes (24 bit = 24 dots vertikal)
      for (int x = 0; x < grayscale.width; x++) {
        for (int k = 0; k < 3; k++) {
          int slice = 0;
          for (int b = 0; b < 8; b++) {
            int row = y + k * 8 + b;
            if (row < height) {
              // Ambil luminance pixel
              final pixel = grayscale.getPixel(x, row);
              final luminance = img.getLuminance(pixel);
              // Threshold: jika gelap (< 128), set bit = 1 (cetak titik hitam)
              if (luminance < 128) {
                slice |= (1 << (7 - b));
              }
            }
          }
          escPosBytes.add(slice);
        }
      }

      // Line feed setelah setiap strip 24 dot
      escPosBytes.addAll([0x0A]);
    }

    // Reset line spacing ke default
    escPosBytes.addAll([0x1B, 0x32]); // ESC 2

    // Feed beberapa baris kosong untuk area pemotongan kertas
    escPosBytes.addAll([0x0A, 0x0A, 0x0A, 0x0A]);

    return escPosBytes;
  }
}
