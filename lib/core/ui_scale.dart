import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overall zoom for phones. The UI was designed for tablet-size screens, so on
/// a phone everything looks oversized and eats the screen. The whole app is
/// laid out on a virtual canvas 1/scale times bigger than the real screen and
/// shrunk to fit, like lowering the display density. 1.0 = no change; lower
/// is smaller (0.85 = about 15% smaller). Tablets, desktop and web are never
/// scaled.
const double kPhoneUiScale = 0.85;

/// Tells descendants the current UI scale (1.0 when not scaled). Platform
/// views such as the AdMob banner need it to cancel the scale out, because
/// native views can't be shrunk by Flutter's transforms.
class UiScale extends InheritedWidget {
  const UiScale({super.key, required this.scale, required super.child});

  final double scale;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiScale>()?.scale ?? 1.0;

  @override
  bool updateShouldNotify(UiScale oldWidget) => oldWidget.scale != scale;
}

/// Applies [kPhoneUiScale] on phones (Android/iOS with a shortest side under
/// 600 logical pixels). Placed in `MaterialApp.builder`, so dialogs, sheets
/// and every screen are scaled together.
class PhoneUiScaler extends StatelessWidget {
  const PhoneUiScaler({super.key, required this.child});

  final Widget child;

  static bool _isPhone(MediaQueryData mq) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      mq.size.shortestSide < 600;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (!_isPhone(mq) || kPhoneUiScale == 1.0) return child;

    const s = kPhoneUiScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth / s;
        final h = constraints.maxHeight / s;
        return FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: w,
            height: h,
            child: UiScale(
              scale: s,
              child: MediaQuery(
                data: mq.copyWith(
                  size: Size(w, h),
                  padding: mq.padding / s,
                  viewPadding: mq.viewPadding / s,
                  viewInsets: mq.viewInsets / s,
                  systemGestureInsets: mq.systemGestureInsets / s,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
