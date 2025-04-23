class Token {
  String name;
  String image;
  String attachedTo = '';
  bool unlimited = false;
  bool needsSetup = false;

  Token({
    required this.name,
    required this.image,
    this.needsSetup = false,
    this.unlimited = false,
  });
  // Methode zum Erstellen eines Token-Objekts aus JSON
  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      name: json['name'] as String,
      image: json['image'] as String,
      unlimited: json['unlimited'] != null ? json['unlimited'] as bool : false,
      needsSetup:
          json['needsSetup'] != null ? json['needsSetup'] as bool : false,
    );
  }

  // Methode zum Konvertieren der Card-Instanz in JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'image': image,
      'unlimited': unlimited,
      'needsSetup': needsSetup,
    };
  }

  get getName => name;
  get getImage => image;
  get getAttachedTo => attachedTo;
  get getUnlimited => unlimited;
  get getNeedsSetup => needsSetup;
}
