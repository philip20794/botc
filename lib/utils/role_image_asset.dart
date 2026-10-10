const _fallbackRoleImageAsset = 'assets/images/backgrounds/token.png';

String roleImageAssetPath(String image) {
  return image.isEmpty
      ? _fallbackRoleImageAsset
      : image.contains('.')
          ? 'assets/images/characters/$image'
          : 'assets/images/characters/$image.png';
}
