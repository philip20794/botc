const _fallbackRoleImageAsset = 'assets/images/backgrounds/token.png';
const _characterImageDirectory = 'assets/images/characters/';

// Character JSON normally stores the icon basename. Keep the file-format
// knowledge in one place so every existing AssetImage caller supports both
// formats without changing role data.
const _webpCharacterImages = <String>{
  'Icon_bigwig',
  'Icon_cacklejack',
  'Icon_deusexfiasco',
  'Icon_godofug',
  'Icon_hermit',
  'Icon_hindu',
  'Icon_knaves',
  'Icon_pope',
  'Icon_princess',
  'Icon_tor',
  'Icon_ventriloquist',
  'Icon_wraith',
  'Icon_zenomancer',
};

String roleImageAssetPath(String image) {
  final name = image.trim();
  if (name.isEmpty) return _fallbackRoleImageAsset;
  if (RegExp(r'\.(png|webp)$', caseSensitive: false).hasMatch(name)) {
    return '$_characterImageDirectory$name';
  }
  final extension = _webpCharacterImages.contains(name) ? '.webp' : '.png';
  return '$_characterImageDirectory$name$extension';
}
