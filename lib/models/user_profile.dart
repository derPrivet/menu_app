class UserProfile {
  String name;
  String gender;
  int age;
  double height;
  double weight;
  double targetWeight;
  String activityLevel;
  String formula;
  String goal; // <-- НОВОЕ ПОЛЕ: 'lose', 'maintain', 'gain'

  UserProfile({
    this.name = '',
    this.gender = 'female',
    this.age = 30,
    this.height = 165,
    this.weight = 65,
    this.targetWeight = 60,
    this.activityLevel = 'light',
    this.formula = 'mifflin',
    this.goal = 'lose', // По умолчанию - похудение
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'age': age,
    'height': height,
    'weight': weight,
    'targetWeight': targetWeight,
    'activityLevel': activityLevel,
    'formula': formula,
    'goal': goal,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? '',
    gender: json['gender'] as String? ?? 'female',
    age: json['age'] as int? ?? 30,
    height: (json['height'] as num?)?.toDouble() ?? 165,
    weight: (json['weight'] as num?)?.toDouble() ?? 65,
    targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 60,
    activityLevel: json['activityLevel'] as String? ?? 'light',
    formula: json['formula'] as String? ?? 'mifflin',
    goal: json['goal'] as String? ?? 'lose',
  );
}