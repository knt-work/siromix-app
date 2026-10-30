import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/omr.dart';
import 'package:siromix/data.dart';

void main() {
  final reference = File('assets/templates/abcd-10-v1.png').readAsBytesSync();
  final fixture = File('test/fixtures/ten-132-clean.png').readAsBytesSync();
  Uint8List photo(
    SheetPart part, {
    bool blank = false,
    bool rotate = false,
    bool skew = false,
  }) {
    final source = img.decodeImage(blank ? reference : fixture)!;
    final f = part.frame;
    var image = img.copyCrop(
      source,
      x: (102 + f[0] - 20).round(),
      y: (120 + f[1] - 20).round(),
      width: (f[2] - f[0] + 40).round(),
      height: (f[3] - f[1] + 40).round(),
    );
    image = img.copyResize(
      image,
      width: image.width * 2,
      height: image.height * 2,
    );
    if (rotate) image = img.copyRotate(image, angle: 90);
    if (skew) {
      final canvas = img.Image(
        width: image.width + 100,
        height: image.height + 110,
      )..clear(img.ColorRgb8(245, 245, 245));
      img.compositeImage(canvas, image, dstX: 50, dstY: 50);
      image = img.copyRotate(
        canvas,
        angle: 4,
        interpolation: img.Interpolation.linear,
      );
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 94));
  }

  for (final part in SheetPart.values) {
    test('local ${part.name} crop reads without any outer page corners', () {
      final r = recognizeTenPart({
        'photo': photo(part),
        'reference': reference,
        'part': part.name,
      });
      if (part == SheetPart.candidate) expect(r.digitText, '001286');
      if (part == SheetPart.code) expect(r.digitText, '132');
      if (part == SheetPart.answers) {
        expect(r.answers.map((a) => a.answer).join(), 'ABCDABCDAB');
      }
    });
    test('blank rotated ${part.name} crop remains blank', () {
      final r = recognizeTenPart({
        'photo': photo(part, blank: true, rotate: true),
        'reference': reference,
        'part': part.name,
      });
      if (part == SheetPart.answers) {
        expect(
          r.answers.every((a) => a.state == MarkState.blank),
          true,
          reason: r.answers.map((a) => '${a.state.name}:${a.answer}').join(','),
        );
      } else {
        expect(r.digits.every((a) => a.state == MarkState.blank), true);
      }
    });
    test('wrong region rejected for ${part.name}', () {
      final wrong = SheetPart.values[(part.index + 1) % 3];
      expect(
        () => recognizeTenPart({
          'photo': photo(wrong),
          'reference': reference,
          'part': part.name,
        }),
        throwsA(isA<OmrException>()),
      );
    });
  }
  test('mildly rotated local capture still reads leading zeros', () {
    final r = recognizeTenPart({
      'photo': photo(SheetPart.candidate, skew: true),
      'reference': reference,
      'part': 'candidate',
    });
    expect(r.digitText, '001286');
  });

  test('live part probes recognize downsampled local frames and reject clipped borders', () {
    for (final part in SheetPart.values) {
      final image = img.decodeImage(photo(part))!;
      final small = img.copyResize(image, height: 800);
      final pixels = Uint8List(small.width * small.height);
      for (var y = 0; y < small.height; y++) {
        for (var x = 0; x < small.width; x++) {
          final p = small.getPixel(x, y);
          pixels[y * small.width + x] =
              ((p.r * 299 + p.g * 587 + p.b * 114) / 1000).round();
        }
      }
      final live = probeTenPart({
        'width': small.width,
        'height': small.height,
        'pixels': pixels,
        'part': part.name,
      });
      expect(live.found, true, reason: part.name);
      final clipped = img.copyCrop(
        image,
        x: 0,
        y: 0,
        width: (image.width * .78).round(),
        height: image.height,
      );
      expect(
        () => recognizeTenPart({
          'photo': Uint8List.fromList(img.encodePng(clipped)),
          'reference': reference,
          'part': part.name,
        }),
        throwsA(isA<OmrException>()),
      );
    }
  });

  for (final part in SheetPart.values) {
    test(
      '${part.name} aligns from its real marker count without printed rectangle',
      () {
        final image = img.decodeImage(photo(part))!;
        final white = img.ColorRgb8(255, 255, 255);
        img.fillRect(
          image,
          x1: 36,
          y1: 0,
          x2: 44,
          y2: image.height - 1,
          color: white,
        );
        img.fillRect(
          image,
          x1: image.width - 44,
          y1: 0,
          x2: image.width - 36,
          y2: image.height - 1,
          color: white,
        );
        img.fillRect(
          image,
          x1: 0,
          y1: 36,
          x2: image.width - 1,
          y2: 44,
          color: white,
        );
        img.fillRect(
          image,
          x1: 0,
          y1: image.height - 44,
          x2: image.width - 1,
          y2: image.height - 36,
          color: white,
        );
        final r = recognizeTenPart({
          'photo': Uint8List.fromList(img.encodePng(image)),
          'reference': reference,
          'part': part.name,
        });
        if (part == SheetPart.candidate) {
          expect(r.digitText, '001286');
        }
        if (part == SheetPart.code) {
          expect(r.digitText, '132');
        }
        if (part == SheetPart.answers) {
          expect(r.answers.map((a) => a.answer).join(), 'ABCDABCDAB');
        }
      },
    );
    test(
      'user supplied ${part.name} example never invents a selected answer',
      () {
        final r = recognizeTenPart({
          'photo': File('test/fixtures/part-${part.name}-user.png')
              .readAsBytesSync(),
          'reference': reference,
          'part': part.name,
        });
        if (part == SheetPart.answers) {
          expect(
            r.answers.every(
              (a) =>
                  a.state == MarkState.blank || a.state == MarkState.uncertain,
            ),
            true,
            reason: r.answers
                .map((a) => '${a.state.name}:${a.answer}')
                .join(','),
          );
        } else {
          expect(r.digits.every((d) => d.state == MarkState.blank), true);
        }
      },
    );
  }

  test(
    'four-marker answers orient correctly when the paper is upside down',
    () {
      final source = img.decodeImage(photo(SheetPart.answers))!;
      final turned = img.copyRotate(source, angle: 180);
      final r = recognizeTenPart({
        'photo': Uint8List.fromList(img.encodePng(turned)),
        'reference': reference,
        'part': 'answers',
      });
      expect(r.answers.map((a) => a.answer).join(), 'ABCDABCDAB');
    },
  );
}
