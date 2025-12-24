import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Future<T?> showBaseBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool dismissible = false,
  bool enableDrag = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: enableDrag,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16.r),
      ),
    ),
    builder: (ctx) {
      return WillPopScope(
        onWillPop: () async {
          if (dismissible) return true;

          final shouldClose = await showDialog<bool>(
            context: ctx,
            builder: (dctx) => AlertDialog(
              title: const Text('Discard changes?'),
              content: const Text('Discard changes and close this form?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dctx).pop(true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldClose == true;
        },
        child: _BottomSheetContainer(child: child),
      );
    },
  );
}

class _BottomSheetContainer extends StatelessWidget {
  final Widget child;

  const _BottomSheetContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        bottom: bottomInset,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16.r),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle（即使不能拖，也作为视觉提示）
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

