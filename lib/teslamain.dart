import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:teslademo/controlpage.dart';
import 'package:teslademo/widgets/assets.dart';
import 'package:teslademo/widgets/carmodel.dart';
import 'package:teslademo/widgets/widgets.dart';

class TeslaPage extends StatefulWidget {
  const TeslaPage({super.key});

  @override
  State<TeslaPage> createState() => _TeslaPageState();
}

class _TeslaPageState extends State<TeslaPage> {
  final Map<String, bool> isOpen = {};

  final teslaController = TeslaController();
  bool isDoorOpen = false;
  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF161718);
    //0xFF131416
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Stack(
            // fit: StackFit.expand,
            // crossAxisAlignment: CrossAxisAlignment.start,
            // spacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        spacing: 5,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Column(children: [tText(data: 'Model 3')]),
                          Row(
                            spacing: 10,
                            children: [
                              tSvg(data: bar, height: 20),
                              tText(
                                data: '69%',
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          tText(
                            data: 'Parked',
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                      CircleAvatar(radius: 20, backgroundColor: Colors.grey),
                    ],
                  ),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.center,
                      heightFactor: 0.7,
                      child: SizedBox(
                        height: 350,
                        width: double.infinity,
                        child: Tesla3D(
                          backgroundColor: Colors.transparent,
                          controller: teslaController,
                          assetPath: 'assets/model/tesla.glb',
                          onLoaded: (car) {
                            car.setView(TeslaView.home);
                            car.setBloom(false);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                top: MediaQuery.sizeOf(context).height * 0.4,
                child: ListView(
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () {
                            teslaController.togglePart(TeslaPart.bonnet);
                          },
                          child: tSvg(
                            data: front,
                            color: (isOpen['bonnet'] ?? false)
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            teslaController.flashLights();
                          },
                          child: tSvg(
                            data: light,
                            color: Colors.grey,
                            height: 20,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            teslaController.toggleParts(TeslaController.doors);
                          },
                          child: tSvg(
                            data: door,
                            color: (isOpen['doors'] ?? false)
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            teslaController.togglePart(TeslaPart.boot);
                          },
                          child: tSvg(
                            data: trunk,
                            color: (isOpen['boot'] ?? false)
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Gap(30),

                    Column(
                      children:
                          [
                            [car, 'Controls', ''],
                            [fan, 'Climate', 'Interior 20°C'],
                            [location, 'Location', 'Tesla Headquarters'],
                            [steering, 'Summon', ''],
                            [secure, 'Security', ''],
                          ].map((t) {
                            return ListTile(
                              onTap: () {
                                // if (t[1].toString() == 'Controls') {
                                //   setControl();
                                // }
                              },
                              contentPadding: EdgeInsets.all(0),
                              leading: tSvg(
                                data: t[0].toString(),
                                color: Colors.grey,
                                //height: t[0] == car ? 30 : 25,
                              ),
                              title: tText(data: t[1].toString()),

                              subtitle: t[2] != ''
                                  ? tText(
                                      data: t[2].toString(),
                                      fontSize: 14,
                                      color: Colors.grey,
                                    )
                                  : null,
                              trailing: Icon(
                                Icons.keyboard_arrow_right_outlined,
                                color: Colors.grey,
                              ),
                            );
                          }).toList(),
                    ),
                    Divider(color: Colors.grey.shade800),
                    Gap(15),
                    tText(data: 'Model 3', fontSize: 30),
                    tText(data: 'Long Range', fontSize: 16, color: Colors.grey),
                    Gap(10),
                    tText(data: '420 km', fontSize: 14, color: Colors.grey),
                    tText(
                      data: 'VIN: 5yji90000000000000000',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    tText(
                      data: 'Software: 2024.4.20',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
