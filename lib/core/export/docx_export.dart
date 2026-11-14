/// Print-oriented Word document writer.
///
/// A `.docx` is a zip of WordprocessingML parts. The needed subset is small
/// enough to emit directly from the same block model the PDF writer uses, which
/// keeps both print formats visually consistent and avoids a template file that
/// could drift from the content.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'image_size.dart';
import 'markdown_blocks.dart';
import 'study_export.dart';

/// A4 usable width inside the default margins (twips: 11906 - 2 * 1134).
const _pageWidthTwips = 9638;

/// A4 usable width in English Metric Units (1 twip = 635 EMU).
const _pageWidthEmu = _pageWidthTwips * 635;
const _maxImageHeightEmu = 4400000;

const _eastAsianFont = '宋体';
const _latinFont = 'Calibri';

Uint8List buildStudyDocx({
  required StudyExportBundle bundle,
  required StudyExportChrome chrome,
  bool includeImages = true,
}) {
  final writer = _DocxWriter();
  writer.heading(1, chrome.title);
  writer.paragraph([MdRun(chrome.dateLine)], style: 'Meta');
  for (final entry in bundle.bySubject.entries) {
    if (bundle.bySubject.length > 1) writer.heading(2, entry.key);
    for (final note in entry.value) {
      writer.heading(2, note.title);
      writer.paragraph([MdRun(chrome.noteMeta(note))], style: 'Meta');
      for (final block in parseLearningMarkdown(note.content).blocks) {
        writer.block(block);
      }
      if (includeImages) {
        for (final image in note.images) {
          writer.image(image);
        }
      }
    }
  }
  return writer.build();
}

class _DocxWriter {
  final _body = StringBuffer();
  final _media = <String, Uint8List>{};
  final _imageRels = <String, String>{};
  var _imageCount = 0;
  var _drawingId = 1;

  Uint8List build() {
    final archive = Archive();
    void addText(String name, String content) =>
        archive.addFile(ArchiveFile.string(name, content));

    addText('[Content_Types].xml', _contentTypes(_media));
    addText('_rels/.rels', _rootRels());
    addText('word/document.xml', _document(_body));
    addText('word/styles.xml', _styles());
    addText('word/_rels/document.xml.rels', _documentRels(_imageRels));
    addText('word/footer1.xml', _footer());
    _media.forEach((name, bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });
    final encoded = ZipEncoder().encode(archive);
    return encoded is Uint8List ? encoded : Uint8List.fromList(encoded);
  }

  void heading(int level, String text) {
    _body.write(
      _paragraph(_runs([MdRun(text)], bold: level > 1), style: 'Heading$level'),
    );
  }

  void paragraph(List<MdRun> runs, {String style = ''}) {
    if (plainText(runs).trim().isEmpty) return;
    _body.write(_paragraph(_runs(runs), style: style));
  }

  void block(MdBlock block) {
    switch (block.kind) {
      case MdBlockKind.rule:
        _body.write(
          '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" '
          'w:space="1" w:color="999999"/></w:pBdr></w:pPr></w:p>',
        );
      case MdBlockKind.heading:
        _body.write(
          _paragraph(
            _runs(block.runs, bold: true),
            style: 'Heading${math.min(block.level + 1, 3)}',
            indent: block.quote ? 240 : 0,
          ),
        );
      case MdBlockKind.code:
        for (final line in plainText(block.runs).split('\n')) {
          _body.write(_paragraph(_run(line), style: 'Code'));
        }
      case MdBlockKind.formula:
        _body.write(
          _paragraph(_runs(block.runs, italic: true), style: 'Formula'),
        );
      case MdBlockKind.bulletList:
      case MdBlockKind.orderList:
        _body.write(
          _paragraph(
            '${_run(block.marker)}${_runs(block.runs)}',
            style: 'List',
            indent: 240 + (block.listDepth - 1) * 240,
          ),
        );
      case MdBlockKind.table:
        _body.write(_table(block));
      case MdBlockKind.paragraph:
        _body.write(
          _paragraph(_runs(block.runs), style: block.quote ? 'Quote' : ''),
        );
    }
  }

  void image(StudyExportImage image) {
    final extension = image.isPng
        ? 'png'
        : image.isJpeg
        ? 'jpeg'
        : null;
    if (extension == null) return;
    final size = imagePixelSize(image.bytes);
    if (size == null) return;
    final (pixelWidth, pixelHeight) = size;
    if (pixelWidth <= 0 || pixelHeight <= 0) return;
    var width = math.min(pixelWidth * 9525, _pageWidthEmu);
    var height = (width * pixelHeight / pixelWidth).round();
    if (height > _maxImageHeightEmu) {
      width = (width * _maxImageHeightEmu / height).round();
      height = _maxImageHeightEmu;
    }
    _imageCount++;
    final name = 'image$_imageCount.$extension';
    final mediaPath = 'word/media/$name';
    _media[mediaPath] = image.bytes;
    final relId = 'rIdImg$_imageCount';
    _imageRels[relId] = 'media/$name';
    final id = _drawingId++;
    _body.write(
      '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing>'
      '<wp:inline distT="0" distB="0" distL="0" distR="0">'
      '<wp:extent cx="$width" cy="$height"/>'
      '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
      '<wp:docPr id="$id" name="Picture $id"/>'
      '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/>'
      '</wp:cNvGraphicFramePr>'
      '<a:graphic><a:graphicData '
      'uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="$name"/>'
      '<pic:cNvPicPr/></pic:nvPicPr>'
      '<pic:blipFill><a:blip r:embed="$relId"/>'
      '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
      '<pic:spPr><a:xfrm><a:off x="0" y="0"/>'
      '<a:ext cx="$width" cy="$height"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
      '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>'
      '</w:r></w:p>',
    );
  }

  String _table(MdBlock block) {
    final columns = block.rows
        .map((row) => row.cells.length)
        .fold(1, (max, count) => math.max(max, count));
    final width = (_pageWidthTwips / columns).floor();
    final out = StringBuffer()
      ..write(
        '<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/>'
        '<w:tblBorders>'
        '${['top', 'left', 'bottom', 'right', 'insideH', 'insideV'].map((side) => '<w:$side w:val="single" w:sz="4" w:space="0" w:color="808080"/>').join()}'
        '</w:tblBorders></w:tblPr><w:tblGrid>',
      );
    for (var i = 0; i < columns; i++) {
      out.write('<w:gridCol w:w="$width"/>');
    }
    out.write('</w:tblGrid>');
    for (final row in block.rows) {
      out.write('<w:tr>');
      for (var i = 0; i < columns; i++) {
        out.write(
          '<w:tc><w:tcPr>'
          '${row.header ? '<w:shd w:val="clear" w:color="auto" w:fill="EEEEEE"/>' : ''}'
          '</w:tcPr>',
        );
        final cells = i < row.cells.length ? row.cells[i] : const <MdRun>[];
        out.write(
          _paragraph(_runs(cells, bold: row.header), style: 'TableText'),
        );
        out.write('</w:tc>');
      }
      out.write('</w:tr>');
    }
    out.write('</w:tbl>');
    // Word ends a table with a paragraph; an empty one keeps the flow stable.
    out.write('<w:p/>');
    return out.toString();
  }
}

String _paragraph(String runsXml, {String style = '', int indent = 0}) {
  final properties = StringBuffer();
  if (style.isNotEmpty) properties.write('<w:pStyle w:val="$style"/>');
  if (indent > 0) {
    properties.write('<w:ind w:left="$indent" w:hanging="$indent"/>');
  }
  if (properties.isEmpty) return '<w:p>$runsXml</w:p>';
  return '<w:p><w:pPr>$properties</w:pPr>$runsXml</w:p>';
}

String _runs(List<MdRun> runs, {bool bold = false, bool italic = false}) => [
  for (final run in runs)
    if (run.text.isNotEmpty)
      _run(
        run.text,
        bold: bold || run.bold,
        italic: italic || run.italic || run.math,
        code: run.code,
      ),
].join();

String _run(
  String text, {
  bool bold = false,
  bool italic = false,
  bool code = false,
}) {
  final properties = <String>[];
  if (code) {
    properties.add(
      '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" '
      'w:eastAsia="$_eastAsianFont"/>',
    );
  }
  if (bold) properties.add('<w:b/><w:bCs/>');
  if (italic) properties.add('<w:i/><w:iCs/>');
  if (code) properties.add('<w:color w:val="444444"/><w:sz w:val="18"/>');
  final open = properties.isEmpty ? '' : '<w:rPr>${properties.join()}</w:rPr>';
  final escaped = _escape(text).replaceAll('\n', '<w:br/>');
  return '<w:r>$open<w:t xml:space="preserve">$escaped</w:t></w:r>';
}

String _escape(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    // XML 1.0 rejects most control characters; drop them instead of writing a
    // document Word refuses to open.
    if (rune < 0x20 && rune != 0x09 && rune != 0x0a) continue;
    out.write(switch (rune) {
      0x26 => '&amp;',
      0x3c => '&lt;',
      0x3e => '&gt;',
      0x22 => '&quot;',
      0x27 => '&apos;',
      _ => String.fromCharCode(rune),
    });
  }
  return out.toString();
}

String _contentTypes(Map<String, Uint8List> media) {
  final extensions = <String>{
    for (final name in media.keys)
      if (name.contains('.')) name.split('.').last,
  };
  final imageDefaults = {
    'png': 'image/png',
    'jpeg': 'image/jpeg',
  }.entries.where((entry) => extensions.contains(entry.key));
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '${imageDefaults.map((entry) => '<Default Extension="${entry.key}" ContentType="${entry.value}"/>').join()}'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
      '</Types>';
}

String _rootRels() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '</Relationships>';

String _documentRels(Map<String, String> imageRels) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rIdFooter1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>'
    '${imageRels.entries.map((entry) => '<Relationship Id="${entry.key}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="${entry.value}"/>').join()}'
    '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

String _footer() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<w:p><w:pPr><w:jc w:val="right"/></w:pPr>'
    '<w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:fldChar w:fldCharType="begin"/></w:r>'
    '<w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
    '<w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:fldChar w:fldCharType="separate"/></w:r>'
    '<w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:t>1</w:t></w:r>'
    '<w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:fldChar w:fldCharType="end"/></w:r>'
    '</w:p></w:ftr>';

String _document(StringBuffer body) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:document '
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
    'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
    '<w:body>$body'
    '<w:sectPr>'
    '<w:footerReference w:type="default" r:id="rIdFooter1"/>'
    '<w:pgSz w:w="11906" w:h="16838"/>'
    '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" '
    'w:header="720" w:footer="720" w:gutter="0"/>'
    '</w:sectPr></w:body></w:document>';

String _styles() =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:docDefaults>'
    '<w:rPrDefault><w:rPr>'
    '<w:rFonts w:ascii="$_latinFont" w:hAnsi="$_latinFont" w:eastAsia="$_eastAsianFont" w:cs="$_latinFont"/>'
    '<w:sz w:val="21"/><w:szCs w:val="21"/>'
    '<w:lang w:val="en-US" w:eastAsia="zh-CN"/>'
    '</w:rPr></w:rPrDefault>'
    '<w:pPrDefault><w:pPr>'
    '<w:spacing w:after="110" w:line="300" w:lineRule="auto"/>'
    '</w:pPr></w:pPrDefault>'
    '</w:docDefaults>'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
    '<w:name w:val="Normal"/><w:qFormat/></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading1">'
    '<w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>'
    '<w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="240" w:after="120"/>'
    '<w:outlineLvl w:val="0"/></w:pPr>'
    '<w:rPr><w:b/><w:bCs/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading2">'
    '<w:name w:val="heading 2"/><w:basedOn w:val="Normal"/>'
    '<w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="220" w:after="80"/>'
    '<w:outlineLvl w:val="1"/></w:pPr>'
    '<w:rPr><w:b/><w:bCs/><w:sz w:val="26"/><w:szCs w:val="26"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading3">'
    '<w:name w:val="heading 3"/><w:basedOn w:val="Normal"/>'
    '<w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="180" w:after="60"/>'
    '<w:outlineLvl w:val="2"/></w:pPr>'
    '<w:rPr><w:b/><w:bCs/><w:sz w:val="23"/><w:szCs w:val="23"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Meta">'
    '<w:name w:val="Meta"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:spacing w:before="0" w:after="80"/></w:pPr>'
    '<w:rPr><w:color w:val="666666"/><w:sz w:val="17"/><w:szCs w:val="17"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Quote">'
    '<w:name w:val="Quote"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:ind w:left="340"/><w:pBdr><w:left w:val="single" w:sz="12" w:space="6" w:color="BBBBBB"/></w:pBdr></w:pPr>'
    '<w:rPr><w:color w:val="555555"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Code">'
    '<w:name w:val="Code"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/>'
    '<w:ind w:left="120"/><w:shd w:val="clear" w:color="auto" w:fill="F5F5F5"/></w:pPr>'
    '<w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>'
    '<w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Formula">'
    '<w:name w:val="Formula"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:jc w:val="center"/></w:pPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="List">'
    '<w:name w:val="List"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:spacing w:after="40"/><w:ind w:left="240" w:hanging="240"/></w:pPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="TableText">'
    '<w:name w:val="TableText"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>'
    '<w:rPr><w:sz w:val="19"/><w:szCs w:val="19"/></w:rPr></w:style>'
    '</w:styles>';
