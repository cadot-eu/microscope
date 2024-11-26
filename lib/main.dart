import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(home: MicroscopeApp(cameras: cameras)));
}

class MicroscopeApp extends StatefulWidget {
  const MicroscopeApp({super.key, required this.cameras});
  final List<CameraDescription> cameras;

  @override
  State<MicroscopeApp> createState() => _MicroscopeAppState();
}

class _MicroscopeAppState extends State<MicroscopeApp> {
  late CameraController _cameraController;
  bool _isTorchOn = false;
  double _scaleFactor = 1.0;
  bool _isImageFrozen = false;
  XFile? _frozenImage;

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _cameraController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _toggleTorch() async {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    await _cameraController
        .setFlashMode(_isTorchOn ? FlashMode.torch : FlashMode.off);
  }

  void _toggleImageFreeze() async {
    if (_isImageFrozen) {
      // Défiger l'image
      setState(() {
        _isImageFrozen = false;
        _frozenImage = null;
      });
    } else {
      // Figer l'image
      try {
        final image = await _cameraController.takePicture();
        setState(() {
          _isImageFrozen = true;
          _frozenImage = image;
        });
      } catch (e) {
        print('Erreur lors de la capture d\'image: $e');
      }
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Augmenter la sensibilité du zoom (divisez par une valeur plus petite)
      _scaleFactor =
          (_scaleFactor * (1 + details.delta.dy / 100)).clamp(1.0, 10.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: GestureDetector(
        onTap: _toggleImageFreeze,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Affichage de l'image figée ou du flux caméra
            _isImageFrozen && _frozenImage != null
                ? Image.file(
                    File(_frozenImage!.path),
                    fit: BoxFit.cover,
                  )
                : Transform.scale(
                    scale: _scaleFactor,
                    alignment: Alignment.center,
                    child: CameraPreview(_cameraController),
                  ),

            // Bouton de la torche
            Positioned(
              top: 30,
              right: 10,
              child: IconButton(
                icon: Icon(
                  _isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                ),
                onPressed: _toggleTorch,
              ),
            ),

            // Indicateur de zoom
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Zoom: ${_scaleFactor.toStringAsFixed(2)}x',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
