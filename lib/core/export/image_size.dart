/// Pixel size of a PNG or JPEG attachment, read from the header bytes.
///
/// DOCX drawing extents are absolute, so the writer needs the real aspect ratio
/// without decoding the full image.
library;

import 'dart:typed_data';

/// Returns `(width, height)` in pixels, or null for a format we cannot read.
(int, int)? imagePixelSize(Uint8List bytes) {
  if (bytes.length > 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes);
    return (data.getUint32(16), data.getUint32(20));
  }
  if (bytes.length > 4 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    var offset = 2;
    while (offset + 9 < bytes.length) {
      if (bytes[offset] != 0xff) {
        offset++;
        continue;
      }
      final marker = bytes[offset + 1];
      // Standalone markers carry no length.
      if (marker == 0xd8 ||
          marker == 0x01 ||
          (marker >= 0xd0 && marker <= 0xd7)) {
        offset += 2;
        continue;
      }
      if (marker == 0xd9 || marker == 0xda) return null;
      final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
      if (length < 2) return null;
      final isStartOfFrame =
          marker >= 0xc0 &&
          marker <= 0xcf &&
          marker != 0xc4 &&
          marker != 0xc8 &&
          marker != 0xcc;
      if (isStartOfFrame) {
        final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
        final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
        return width > 0 && height > 0 ? (width, height) : null;
      }
      offset += 2 + length;
    }
  }
  return null;
}
