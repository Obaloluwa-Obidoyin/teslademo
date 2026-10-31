import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Tesla3D: a 3D car in a WebView, driven from Dart.
//
// pubspec.yaml: add webview_flutter, and list your model under assets.
// Android: add the INTERNET permission to AndroidManifest.xml (three.js loads from a CDN).
//
//   final car = TeslaController();          // keep it in your State, not inside build()
//
//   Tesla3D(
//     controller: car,
//     assetPath: 'assets/model/tesla.glb',
//     onLoaded: (car) => car.setView(TeslaView.home),
//   )
//
//   car.togglePart(TeslaPart.bonnet);
//   car.toggleParts(TeslaController.doors);
//   car.flashLights();

/// Axis of the parent that a part rotates around.
enum TeslaAxis { x, y, z }

/// The parts that open and close.
enum TeslaPart {
  doorFrontLeft,
  doorFrontRight,
  doorRearLeft,
  doorRearRight,
  bonnet,
  boot,
}

/// Camera presets. azimuth and polar are degrees, distance is a multiple of the car size.
/// polar 0 looks straight down, 90 is level with the car.
enum TeslaView {
  home(39, 75, 1.7),
  front(0, 80, 1.7),
  rear(180, 80, 1.7),
  left(90, 80, 1.7),
  right(-90, 80, 1.7),
  top(180, 0, 1.9);

  const TeslaView(this.azimuth, this.polar, this.distance);
  final double azimuth;
  final double polar;
  final double distance;
}

/// How one part swings. node is the name, or the start of the name, of the part in the model.
class TeslaPartSetup {
  TeslaPartSetup(this.node, this.axis, this.angle);
  String node;
  TeslaAxis axis;

  /// Degrees when open. Flip the sign to swing the other way.
  double angle;
}

/// Converts a Color to the hex text the page understands, for example #131416.
String teslaHex(Color color) {
  // ignore: deprecated_member_use
  final argb = color.value;
  if ((argb >> 24) == 0) return 'transparent';
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

/// Drives the camera, the whole model and individual body parts from Dart.
class TeslaController extends ChangeNotifier {
  static const List<TeslaPart> doors = [
    TeslaPart.doorFrontLeft,
    TeslaPart.doorFrontRight,
    TeslaPart.doorRearLeft,
    TeslaPart.doorRearRight,
  ];

  WebViewController? web;
  bool loaded = false;
  bool interactive = true;
  final Completer<void> ready = Completer<void>();
  final List<void Function()> queue = [];

  /// Filled in when the model has loaded. Camera distances are multiples of modelSize.
  double modelSize = 1.0;
  List<double> modelCenter = [0.0, 0.0, 0.0];

  // PART SETTINGS: change these if a part swings the wrong way or too far.
  final Map<TeslaPart, TeslaPartSetup> setups = {
    TeslaPart.doorFrontLeft: TeslaPartSetup('door_lf_dummy', TeslaAxis.z, -65),
    TeslaPart.doorFrontRight: TeslaPartSetup('door_rf_dummy', TeslaAxis.z, 65),
    TeslaPart.doorRearLeft: TeslaPartSetup('door_lr_dummy', TeslaAxis.z, -65),
    TeslaPart.doorRearRight: TeslaPartSetup('door_rr_dummy', TeslaAxis.z, 65),
    TeslaPart.bonnet: TeslaPartSetup('bonnet_dummy', TeslaAxis.x, 55),
    TeslaPart.boot: TeslaPartSetup('boot_dummy', TeslaAxis.x, -50),
  };
  double openSpeed = 3.0;
  double closeSpeed = 4.0;
  final Map<TeslaPart, bool> openState = {
    for (final part in TeslaPart.values) part: false,
  };

  // LIGHT SETTINGS: names of the lamp objects in the model.
  List<String> headlightNodes = ['Object_425'];
  List<String> taillightNodes = ['Object_279', 'Object_270'];
  String headlightColor = '#d9ebff';
  String taillightColor = '#ff0a00';
  double glowStrength = 5.0;
  bool lightsOn = false;
  bool flashing = false;

  // ATTACHING AND QUEUEING
  void attachController(WebViewController controller, {bool isLoaded = false}) {
    web = controller;
    loaded = isLoaded;
    if (isLoaded) {
      if (!ready.isCompleted) ready.complete();
      flushQueue();
    }
  }

  void detachController() {
    web = null;
    loaded = false;
  }

  void markLoaded(Map<String, dynamic> info) {
    final size = info['size'];
    final center = info['center'];
    if (size is num) modelSize = size.toDouble();
    if (center is List && center.length == 3) {
      modelCenter = center.map((value) => (value as num).toDouble()).toList();
    }
    loaded = true;
    if (!ready.isCompleted) ready.complete();
    flushQueue();
    notifyListeners();
  }

  /// Runs now if the model is loaded, otherwise waits and runs as soon as it is.
  void whenLoaded(void Function() action) {
    if (loaded && web != null) {
      action();
    } else {
      queue.add(action);
    }
  }

  void flushQueue() {
    final pending = List<void Function()>.of(queue);
    queue.clear();
    for (final action in pending) {
      action();
    }
  }

  void send(String js) {
    final controller = web;
    if (controller == null) return;
    controller.runJavaScript(js).catchError((Object error) {
      debugPrint('Tesla3D: $error');
    });
  }

  void run(String js) => whenLoaded(() => send(js));

  // 1. INDIVIDUAL PARTS
  /// Rotates a part by rx, ry, rz radians around its parent's axes, on top of its closed pose.
  /// All zeros means closed. speed is how fast it catches up, bigger is faster.
  void updateMeshTransform({
    required String partName,
    double rx = 0.0,
    double ry = 0.0,
    double rz = 0.0,
    double speed = 5.0,
  }) {
    run("setTransform('$partName', $rx, $ry, $rz, $speed);");
  }

  // 2. THE WHOLE MODEL
  void setModelTransform({
    double posX = 0.0,
    double posY = 0.0,
    double posZ = 0.0,
    double rotX = 0.0,
    double rotY = 0.0,
    double rotZ = 0.0,
  }) {
    run('setModelTransform($posX, $posY, $posZ, $rotX, $rotY, $rotZ);');
  }

  // 3. CAMERA
  /// Moves the camera straight to a position, looking at the target.
  void setCameraPosition({
    double x = 0.0,
    double y = 1.0,
    double z = 4.0,
    double targetX = 0.0,
    double targetY = 0.0,
    double targetZ = 0.0,
  }) {
    run('setCameraPosition($x, $y, $z, $targetX, $targetY, $targetZ);');
  }

  /// Glides around the car. azimuth and polar are degrees, distance is a multiple of the car size.
  void setCameraOrbit({
    double azimuth = 39.0,
    double polar = 75.0,
    double distance = 1.7,
    int ms = 800,
  }) {
    whenLoaded(() {
      send('setCameraOrbit($azimuth, $polar, ${distance * modelSize}, $ms);');
    });
  }

  void setView(TeslaView view, {int ms = 800}) {
    setCameraOrbit(
      azimuth: view.azimuth,
      polar: view.polar,
      distance: view.distance,
      ms: ms,
    );
  }

  /// Only what you pass is changed. Angles are degrees, distances are multiples of the car size.
  /// enabled false lets touches pass through to Flutter. resetLimits puts every limit back.
  void setControls({
    bool? enabled,
    bool? zoom,
    bool? autoRotate,
    double? autoRotateSpeed,
    double? minPolar,
    double? maxPolar,
    double? minAzimuth,
    double? maxAzimuth,
    double? minDistance,
    double? maxDistance,
    bool resetLimits = false,
  }) {
    if (enabled != null) interactive = enabled;
    whenLoaded(() {
      final data = <String, Object?>{};
      if (resetLimits) {
        for (final key in [
          'minPolar',
          'maxPolar',
          'minAzimuth',
          'maxAzimuth',
          'minDistance',
          'maxDistance',
        ]) {
          data[key] = null;
        }
      }
      if (enabled != null) data['enabled'] = enabled;
      if (zoom != null) data['zoom'] = zoom;
      if (autoRotate != null) data['autoRotate'] = autoRotate;
      if (autoRotateSpeed != null) data['autoRotateSpeed'] = autoRotateSpeed;
      if (minPolar != null) data['minPolar'] = minPolar;
      if (maxPolar != null) data['maxPolar'] = maxPolar;
      if (minAzimuth != null) data['minAzimuth'] = minAzimuth;
      if (maxAzimuth != null) data['maxAzimuth'] = maxAzimuth;
      if (minDistance != null) data['minDistance'] = minDistance * modelSize;
      if (maxDistance != null) data['maxDistance'] = maxDistance * modelSize;
      send('setControls(${jsonEncode(data)});');
    });
    notifyListeners();
  }

  // 4. COLOUR AND GLOW
  /// Colours a part. The material is copied first, so parts that share a material are not affected.
  void setPartColor(String partName, String hexColor) {
    run("setMeshColor('$partName', '$hexColor');");
  }

  /// Makes a part glow. Use intensity 0 to turn the glow off.
  void setPartGlow(String partName, String hexColor, double intensity) {
    run("setEmissive('$partName', '$hexColor', $intensity);");
  }

  // LOOK
  void setBackground(String hexColor) => run("setBackground('$hexColor');");
  void setExposure(double value) => run('setExposure($value);');
  void setBloom(bool on, {double? strength}) {
    run('setBloom($on, ${strength ?? 'null'});');
  }

  // HELPERS ON TOP: open and close parts, lights, reset
  bool isOpen(TeslaPart part) => openState[part] ?? false;
  bool get doorsOpen => doors.every(isOpen);

  void setPartsOpen(Iterable<TeslaPart> parts, bool open) {
    for (final part in parts) {
      final setup = setups[part];
      if (setup == null) continue;
      final radians = open ? setup.angle * math.pi / 180.0 : 0.0;
      updateMeshTransform(
        partName: setup.node,
        rx: setup.axis == TeslaAxis.x ? radians : 0.0,
        ry: setup.axis == TeslaAxis.y ? radians : 0.0,
        rz: setup.axis == TeslaAxis.z ? radians : 0.0,
        speed: open ? openSpeed : closeSpeed,
      );
      openState[part] = open;
    }
    notifyListeners();
  }

  void openPart(TeslaPart part) => setPartsOpen([part], true);
  void closePart(TeslaPart part) => setPartsOpen([part], false);
  void togglePart(TeslaPart part) => setPartsOpen([part], !isOpen(part));

  /// If any of the parts is closed they all open, otherwise they all close.
  void toggleParts(Iterable<TeslaPart> parts) {
    final list = parts.toList();
    setPartsOpen(list, list.any((part) => !isOpen(part)));
  }

  void applyLamps(bool on) {
    for (final name in headlightNodes) {
      setPartGlow(
        name,
        on ? headlightColor : '#000000',
        on ? glowStrength : 0.0,
      );
    }
    for (final name in taillightNodes) {
      setPartGlow(
        name,
        on ? taillightColor : '#000000',
        on ? glowStrength : 0.0,
      );
    }
  }

  void setLights(bool on) {
    lightsOn = on;
    applyLamps(on);
    notifyListeners();
  }

  void toggleLights() => setLights(!lightsOn);

  /// Flashes the lights, then returns them to however they were.
  Future<void> flashLights({
    int times = 3,
    Duration onTime = const Duration(milliseconds: 380),
    Duration offTime = const Duration(milliseconds: 280),
  }) async {
    if (flashing) return;
    flashing = true;
    notifyListeners();
    await ready.future;
    for (var count = 0; count < times; count++) {
      applyLamps(true);
      await Future<void>.delayed(onTime);
      applyLamps(lightsOn);
      await Future<void>.delayed(offTime);
    }
    flashing = false;
    notifyListeners();
  }

  /// Closes everything, lights off, camera back to the home view.
  void resetCar() {
    setPartsOpen(TeslaPart.values, false);
    setLights(false);
    setView(TeslaView.home);
  }
}

/// Custom widget wrapper
class Tesla3D extends StatefulWidget {
  const Tesla3D({
    super.key,
    required this.assetPath,
    this.onLoaded,
    this.controller,
    this.backgroundColor = const Color(0xFF131416),
    this.loading,
  });

  /// The .glb in your assets, for example 'assets/model/tesla.glb'.
  final String assetPath;

  /// Called when the car is on screen. Commands sent before this wait and run first.
  final void Function(TeslaController controller)? onLoaded;
  final TeslaController? controller;
  final Color backgroundColor;

  /// Shown on top of the view until the model has loaded.
  final Widget? loading;

  @override
  State<Tesla3D> createState() => Tesla3DState();
}

class Tesla3DState extends State<Tesla3D> {
  late final WebViewController webViewController;
  late TeslaController teslaController;
  bool started = false;

  @override
  void initState() {
    super.initState();
    teslaController = widget.controller ?? TeslaController();

    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor)
      ..addJavaScriptChannel('CarBridge', onMessageReceived: onMessage);

    teslaController.attachController(webViewController);
    loadViewer();
  }

  @override
  void didUpdateWidget(covariant Tesla3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.controller;
    if (next != null && next != teslaController) {
      final previous = teslaController;
      previous.detachController();
      next.modelSize = previous.modelSize;
      next.modelCenter = previous.modelCenter;
      teslaController = next;
      teslaController.attachController(
        webViewController,
        isLoaded: previous.loaded,
      );
    }
  }

  @override
  void dispose() {
    teslaController.detachController();
    super.dispose();
  }

  Future<void> loadViewer() async {
    try {
      await webViewController.loadHtmlString(
        teslaViewerHtml,
        baseUrl: 'https://localhost/',
      );
    } catch (error) {
      debugPrint('Tesla3D: $error');
    }
  }

  void onMessage(JavaScriptMessage message) {
    final text = message.message;
    if (text == 'Ready') {
      sendModel();
      return;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(text) as Map<String, dynamic>;
    } catch (error) {
      return;
    }

    switch (data['type']) {
      case 'loaded':
        teslaController.markLoaded(data);
        widget.onLoaded?.call(teslaController);
        break;
      case 'warn':
        debugPrint('Tesla3D: ${data['message']}');
        break;
      case 'error':
        debugPrint('Tesla3D error: ${data['message']}');
        break;
    }
  }

  /// The .glb goes into the page as base64 pieces, so no web server is needed.
  Future<void> sendModel() async {
    if (started) return;
    started = true;
    try {
      await webViewController.runJavaScript(
        "setBackground('${teslaHex(widget.backgroundColor)}');",
      );
      final data = await rootBundle.load(widget.assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await webViewController.runJavaScript('beginModel();');

      const chunk = 3 * 65536; // a multiple of 3 keeps every base64 piece clean
      for (var start = 0; start < bytes.length; start += chunk) {
        if (!mounted) return;
        final end = math.min(start + chunk, bytes.length);
        final piece = base64Encode(bytes.sublist(start, end));
        await webViewController.runJavaScript("addChunk('$piece');");
      }
      await webViewController.runJavaScript('endModel();');
    } catch (error) {
      debugPrint('Tesla3D: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: teslaController,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: !teslaController.interactive,
              child: WebViewWidget(
                controller: webViewController,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
              ),
            ),
            if (!teslaController.loaded && widget.loading != null)
              Positioned.fill(child: widget.loading!),
          ],
        );
      },
    );
  }
}

/// The page the WebView shows. It only renders and obeys the small commands above.
const String teslaViewerHtml = r'''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body { margin: 0; height: 100%; background: transparent; overflow: hidden; }
  canvas { display: block; }
</style>
<script type="importmap">
{
  "imports": {
    "three": "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js",
    "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"
  }
}
</script>
</head>
<body>
<script type="module">
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

// Messages to Flutter (the TeslaBridge channel)
const post = (o) => { try { CarBridge.postMessage(typeof o === 'string' ? o : JSON.stringify(o)); } catch (e) {} };

// SETUP: renderer, camera, controls, glow
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setClearColor(0x131416, 1);
renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setClearColor(0x131416);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.8;
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.environment = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;

const camera = new THREE.PerspectiveCamera(35, window.innerWidth / window.innerHeight, 0.1, 100);
camera.position.set(4, 2, 6);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.enablePan = false;

const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloomPass = new UnrealBloomPass(new THREE.Vector2(window.innerWidth, window.innerHeight), 0.7, 0.5, 0.85);
composer.addPass(bloomPass);
composer.addPass(new OutputPass());

function resize() {
  const w = window.innerWidth, h = window.innerHeight;
  if (!w || !h) return;
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.setSize(w, h);
  composer.setSize(w, h);
}
window.addEventListener('resize', resize);
if (window.ResizeObserver) new ResizeObserver(resize).observe(document.body);
window.addEventListener('error', (e) => post({ type: 'error', message: e.message }));

// LOGIC START
const DEG = Math.PI / 180;
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

let car = null;
const nodes = {};                 // every named object in the model
const looked = {};                // cache for name lookups
const motion = new Map();         // node -> { rest, cur, tgt, speed }
let tween = null;                 // camera move in progress

// Find a part by its exact name, or by the start of its name (door_lf_dummy finds door_lf_dummy_184).
function findNode(name) {
  if (nodes[name]) return nodes[name];
  if (!(name in looked)) {
    const key = Object.keys(nodes).find((n) => n.startsWith(name));
    looked[name] = key ? nodes[key] : null;
  }
  return looked[name];
}

// PART COMMANDS (Flutter decides, the page just moves)

// Rotate a part by rx, ry, rz radians around its parent's axes, on top of its closed pose.
// All zeros means closed. speed is how fast it catches up, bigger is faster.
window.setTransform = (name, rx = 0, ry = 0, rz = 0, speed = 5) => {
  const node = findNode(name);
  if (!node) return post({ type: 'warn', message: 'No part named ' + name });
  let m = motion.get(node);
  if (!m) {
    m = { rest: node.quaternion.clone(), cur: new THREE.Vector3(), tgt: new THREE.Vector3(), speed };
    motion.set(node, m);
  }
  m.tgt.set(rx, ry, rz);
  m.speed = speed;
};

window.setModelTransform = (px, py, pz, rx, ry, rz) => {
  if (!car) return;
  car.position.set(px, py, pz);
  car.rotation.set(rx, ry, rz);
};

// Colour a part, or make it glow. The material is copied first so shared materials are not affected.
function eachMaterial(name, fn) {
  const root = findNode(name);
  if (!root) return post({ type: 'warn', message: 'No part named ' + name });
  root.traverse((o) => {
    if (!o.isMesh) return;
    if (!o.userData.own) {
      o.material = Array.isArray(o.material) ? o.material.map((m) => m.clone()) : o.material.clone();
      o.userData.own = true;
    }
    (Array.isArray(o.material) ? o.material : [o.material]).forEach(fn);
  });
}
window.setMeshColor = (name, hex) => eachMaterial(name, (m) => m.color && m.color.set(hex));
window.setEmissive = (name, hex, intensity) => eachMaterial(name, (m) => {
  if (!m.emissive) return;
  m.emissive.set(hex);
  m.emissiveIntensity = intensity;
});

// CAMERA COMMANDS
window.setCameraPosition = (x, y, z, tx, ty, tz) => {
  tween = null;
  camera.position.set(x, y, z);
  controls.target.set(tx, ty, tz);
  controls.update();
};

// Move around the car. azimuth and polar are degrees, polar 0 is straight above.
// ms is how long the move takes, 0 jumps straight there.
window.setCameraOrbit = (azimuth, polar, distance, ms = 800) => {
  const from = new THREE.Spherical().setFromVector3(camera.position.clone().sub(controls.target));
  const to = new THREE.Spherical(distance, Math.max(polar * DEG, 0.01), azimuth * DEG);
  const turn = Math.atan2(Math.sin(to.theta - from.theta), Math.cos(to.theta - from.theta)); // shortest way round
  tween = { t0: performance.now(), ms, from, to, turn };
  if (ms <= 0) stepCamera(tween.t0);
};

// Only the keys you send are changed. A null value puts that setting back to its default.
let defaults = { minDistance: 0, maxDistance: Infinity };
window.setControls = (o) => {
  const or = (v, d) => (v === null ? d : v);
  if ('enabled' in o) controls.enabled = !!o.enabled;
  if ('zoom' in o) controls.enableZoom = !!o.zoom;
  if ('autoRotate' in o) controls.autoRotate = !!o.autoRotate;
  if ('autoRotateSpeed' in o) controls.autoRotateSpeed = o.autoRotateSpeed;
  if ('minPolar' in o) controls.minPolarAngle = or(o.minPolar, 0) * DEG;
  if ('maxPolar' in o) controls.maxPolarAngle = or(o.maxPolar, 89) * DEG;
  if ('minAzimuth' in o) controls.minAzimuthAngle = o.minAzimuth === null ? -Infinity : o.minAzimuth * DEG;
  if ('maxAzimuth' in o) controls.maxAzimuthAngle = o.maxAzimuth === null ? Infinity : o.maxAzimuth * DEG;
  if ('minDistance' in o) controls.minDistance = or(o.minDistance, defaults.minDistance);
  if ('maxDistance' in o) controls.maxDistance = or(o.maxDistance, defaults.maxDistance);
};
controls.addEventListener('start', () => { tween = null; }); // if the user grabs the car, they win

// LOOK

window.setBackground = (hex) => {
  if (hex === 'transparent') renderer.setClearColor(0x000000, 0);
  else renderer.setClearColor(hex, 1);
};
window.setExposure = (v) => { renderer.toneMappingExposure = v; };
window.setBloom = (on, strength) => {
  bloomPass.enabled = !!on;
  if (typeof strength === 'number') bloomPass.strength = strength;
};

// MODEL: Flutter sends the .glb in base64 pieces
const loader = new GLTFLoader();
let chunks = [];

window.beginModel = () => { chunks = []; };
window.addChunk = (b64) => {
  const bin = atob(b64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  chunks.push(arr);
};
window.endModel = () => {
  const blob = new Blob(chunks);
  chunks = [];
  blob.arrayBuffer().then((buf) =>
    loader.parse(buf, '', onModel, (e) => post({ type: 'error', message: String((e && e.message) || e) })));
};

function onModel(gltf) {
  if (car) scene.remove(car);
  car = gltf.scene;
  scene.add(car);
  for (const k of Object.keys(nodes)) delete nodes[k];
  for (const k of Object.keys(looked)) delete looked[k];
  motion.clear();
  car.traverse((o) => { if (o.name && !nodes[o.name]) nodes[o.name] = o; });

  const box = new THREE.Box3().setFromObject(car);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  const big = Math.max(size.x, size.y, size.z) || 1;
  camera.near = big / 100;
  camera.far = big * 30;
  camera.updateProjectionMatrix();
  controls.target.copy(center);
  defaults = { minDistance: big * 0.8, maxDistance: big * 3 };
  controls.minDistance = defaults.minDistance;
  controls.maxDistance = defaults.maxDistance;
  controls.maxPolarAngle = 89 * DEG;
  window.setCameraOrbit(39, 75, big * 1.7, 0);

  post({ type: 'loaded', size: big, center: center.toArray() });
}

// FRAME
function stepMotion(dt) {
  const euler = new THREE.Euler();
  const q = new THREE.Quaternion();
  for (const [node, m] of motion) {
    if (m.cur.equals(m.tgt)) continue;
    m.cur.lerp(m.tgt, 1 - Math.exp((-m.speed * dt) / 1000));
    if (m.cur.distanceTo(m.tgt) < 1e-4) m.cur.copy(m.tgt);
    q.setFromEuler(euler.set(m.cur.x, m.cur.y, m.cur.z));
    node.quaternion.copy(m.rest).premultiply(q);
  }
}

function stepCamera(now) {
  if (!tween) return;
  const k = tween.ms <= 0 ? 1 : clamp((now - tween.t0) / tween.ms, 0, 1);
  const e = ease(k);
  const { from, to, turn } = tween;
  const offset = new THREE.Vector3().setFromSphericalCoords(
    from.radius + (to.radius - from.radius) * e,
    from.phi + (to.phi - from.phi) * e,
    from.theta + turn * e
  );
  camera.position.copy(controls.target).add(offset);
  camera.lookAt(controls.target);
  if (k >= 1) tween = null;
}

let last = performance.now();
renderer.setAnimationLoop((now) => {
  const dt = Math.min(64, now - last);
  last = now;
  stepMotion(dt);
  stepCamera(now);
  controls.update();
  composer.render();
});

post('Ready');
// LOGIC END
</script>
</body>
</html>

''';
