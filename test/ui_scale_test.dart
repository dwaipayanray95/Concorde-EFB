import 'package:concorde_efb/core/ui_scale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Size size, void Function(Size, double) onBuild) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: PhoneUiScaler(
          child: Builder(
            builder: (context) {
              onBuild(MediaQuery.of(context).size, UiScale.of(context));
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('phone-size screens are laid out on a larger virtual canvas', (
    tester,
  ) async {
    Size? seen;
    double? scale;
    await tester.pumpWidget(
      _host(const Size(800, 400), (s, k) {
        seen = s;
        scale = k;
      }),
    );
    expect(scale, kPhoneUiScale);
    expect(seen!.width, closeTo(800 / kPhoneUiScale, 0.01));
    expect(seen!.height, closeTo(400 / kPhoneUiScale, 0.01));
  });

  testWidgets('tablet-size screens are left alone', (tester) async {
    Size? seen;
    double? scale;
    await tester.pumpWidget(
      _host(const Size(1280, 800), (s, k) {
        seen = s;
        scale = k;
      }),
    );
    expect(scale, 1.0);
    expect(seen, const Size(1280, 800));
  });
}
