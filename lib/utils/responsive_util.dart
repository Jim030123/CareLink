// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

// class ResponsiveUtil {
//   /// 自适应 Row，支持 flex 占比和间距
//   static Widget row({
//     required List<Widget> children,
//     List<int>? flexes, // 占比，可选
//     double spacing = 10,
//     MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
//   }) {
//     List<Widget> rowChildren = [];
//     for (int i = 0; i < children.length; i++) {
//       Widget child = (flexes != null && i < flexes.length)
//           ? Expanded(flex: flexes[i], child: children[i])
//           : Expanded(child: children[i]);
//       rowChildren.add(child);
//       if (i != children.length - 1) {
//         rowChildren.add(SizedBox(width: spacing.w));
//       }
//     }
//     return Row(
//       mainAxisAlignment: mainAxisAlignment,
//       children: rowChildren,
//     );
//   }
// }
