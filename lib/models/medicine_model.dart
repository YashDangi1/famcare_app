class Medicine {
  String name;
  String dose;
  int morning;
  int afternoon;
  int night;
  String instructions;
  DateTime? morningTime;
  DateTime? afternoonTime;
  DateTime? nightTime;
  String? imagePath;

  Medicine({
    required this.name,
    required this.dose,
    required this.morning,
    required this.afternoon,
    required this.night,
    required this.instructions,
    this.morningTime,
    this.afternoonTime,
    this.nightTime,
    this.imagePath,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      name: json["medicine"] ?? "",
      dose: json["dose"] ?? "",
      morning: json["morning"] ?? 0,
      afternoon: json["afternoon"] ?? 0,
      night: json["night"] ?? 0,
      instructions: json["instructions"] ?? "",
      imagePath: json["image_path"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "medicine": name,
      "dose": dose,
      "morning": morning,
      "afternoon": afternoon,
      "night": night,
      "instructions": instructions,
      "image_path": imagePath,
    };
  }
}