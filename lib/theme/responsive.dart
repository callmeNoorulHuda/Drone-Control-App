import 'package:flutter/widgets.dart';

/// Single shared breakpoint for the whole app. Uses shortestSide (not
/// width) so it correctly classifies a phone in landscape as "phone" even
/// though its width alone might look tablet-sized — 600dp shortest side is
/// the standard Flutter convention for "this is a tablet".
bool isTabletLayout(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}
