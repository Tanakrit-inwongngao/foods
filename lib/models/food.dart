class Food {
  final int id;
  final String nameTh;
  final String nameEn;
  final String region;
  final int protein;
  final int fat;
  final int carbs;
  final int calories;
  final String ingredients;

  Food({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.region,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.calories,
    required this.ingredients,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'],
      nameTh: json['name_th'],
      nameEn: json['name_en'],
      region: json['region'],
      protein: json['protein_g'],
      fat: json['fat_g'],
      carbs: json['carbs_g'],
      calories: json['nutrition'],
      ingredients: json['ingredients'],
    );
  }
}
