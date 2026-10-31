import 'package:flutter/material.dart';

// import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class ControlPage extends StatelessWidget {
  ControlPage({super.key});

  // final Flutter3DController controller = Flutter3DController();

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF131416);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(children: [Column(children: [])]),
      ),
    );
  }
}
// if (false)
//   Column(
//     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//     children: [
//       // Gap(20),
//       Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 15.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             GestureDetector(
//               onTap: () {
//                 //setControl();
//               },
//               child: Icon(Icons.arrow_back_ios),
//             ),
//             tText(
//               data: 'Controls',
//               fontSize: 25,
//               color: Colors.white,
//             ),
//             SizedBox(),
//           ],
//         ),
//       ),
//
//       Expanded(
//         child: Flutter3DViewer(
//           controller: controller,
//           src: 'assets/tesla.glb',
//           enableTouch: false,
//           onLoad: (String modelAddress) async {
//             controller.setCameraOrbit(145, 0, 10);
//             controller.setCameraTarget(0.0, 0.0, 0.0);
//             final clips = await controller.getAvailableAnimations();
//             final textures = await controller
//                 .getAvailableTextures();
//
//             debugPrint('Clips in model: $clips & $textures');
//             print(clips);
//           },
//         ),
//       ),
//
//       // Gap(30),
//       Padding(
//         padding: const EdgeInsets.only(bottom: 10, top: 5),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             GestureDetector(
//               onTap: () {
//                 toggle('bonnet');
//               },
//               child: Column(
//                 spacing: 10,
//                 children: [
//                   tSvg(data: light, color: Colors.grey),
//                   tText(
//                     data: 'Flash',
//                     fontSize: 16,
//                     color: Colors.grey,
//                   ),
//                 ],
//               ),
//             ),
//             GestureDetector(
//               onTap: () {
//                 toggle('light');
//               },
//               child: Column(
//                 spacing: 10,
//                 children: [
//                   tSvg(data: front, color: Colors.grey),
//                   tText(
//                     data: 'Honk',
//                     fontSize: 16,
//                     color: Colors.grey,
//                   ),
//                 ],
//               ),
//             ),
//             GestureDetector(
//               onTap: () {
//                 toggle('door_lr');
//               },
//               child: Column(
//                 spacing: 10,
//                 children: [
//                   tSvg(data: front, color: Colors.grey),
//                   tText(
//                     data: 'Start',
//                     fontSize: 16,
//                     color: Colors.grey,
//                   ),
//                 ],
//               ),
//             ),
//             GestureDetector(
//               onTap: () {
//                 toggle('boot');
//               },
//               child: Column(
//                 spacing: 10,
//                 children: [
//                   tSvg(data: door, color: Colors.grey),
//                   tText(
//                     data: 'Vent',
//                     fontSize: 16,
//                     color: Colors.grey,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
// Gap(20),
//   ],
// ),
// ],
// ),
