import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

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
      ResolutionPreset.max,
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

  Future<void> _toggleImageFreeze() async {
    if (_isImageFrozen) {
      // Défiger l'image
      setState(() {
        _isImageFrozen = false;
        _frozenImage = null;
        _scaleFactor = 1.0;
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

  Future<void> _saveImage() async {
    if (_frozenImage == null) return;

    try {
      // Charger l'image
      final File originalFile = File(_frozenImage!.path);
      final img.Image? originalImage =
          img.decodeImage(originalFile.readAsBytesSync());

      if (originalImage == null) return;

      // Amélioration de l'image
      final img.Image enhancedImage = _enhanceImage(originalImage);

      // Chemin de sauvegarde
      final directory = await getExternalStorageDirectory();
      final String filePath =
          '${directory!.path}/microscope_image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Sauvegarder l'image améliorée
      File(filePath)
          .writeAsBytesSync(img.encodeJpg(enhancedImage, quality: 95));

      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image sauvegardée dans $filePath')),
      );
    } catch (e) {
      print('Erreur lors de la sauvegarde de l\'image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde de l\'image')),
      );
    }
  }

  // Méthode d'amélioration d'image
  img.Image _enhanceImage(img.Image image) {
    // Convertir en niveaux de gris pour améliorer le contraste
    img.Image grayscaleImage = img.grayscale(image);

    // Amélioration du contraste
    img.Image contrastImage = img.adjustColor(
      grayscaleImage,
      contrast: 1.5,
      brightness: 1.2,
    );

    // Réduction du bruit
    img.Image denoisedImage = img.gaussianBlur(contrastImage, radius: 1);

    // Redimensionnement avec interpolation
    img.Image finalImage = img.copyResize(denoisedImage,
        width: denoisedImage.width,
        height: denoisedImage.height,
        interpolation: img.Interpolation.linear);

    return finalImage;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Augmenter la sensibilité du zoom (divisez par une valeur plus petite)
      _scaleFactor =
          (_scaleFactor * (1 + details.delta.dy / 50)).clamp(1.0, 10.0);
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
            // Affichage de l'image figée zoomée ou du flux caméra
            _isImageFrozen && _frozenImage != null
                ? Transform.scale(
                    scale: _scaleFactor,
                    alignment: Alignment.center,
                    child: Image.file(
                      File(_frozenImage!.path),
                      fit: BoxFit.cover,
                    ),
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

            // Bouton de sauvegarde (visible uniquement quand l'image est figée)
            if (_isImageFrozen)
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  onPressed: _saveImage,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.save, color: Colors.black),
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
