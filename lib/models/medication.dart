// import 'dart:convert';

// class Medication {
//   final String id;
//   final String name;
//   final String? description;
//   final int? packageQuantity;
//   final String? standardUnit;
//   final String? picture;
//   final String? form;
//   final String? packageUnit;
//   final String? brand;
//   final String? sku;
//   final String? strength;

//   Medication({
//     required this.id,
//     required this.name,
//     this.description,
//     this.packageQuantity,
//     this.standardUnit,
//     this.picture,
//     this.form,
//     this.packageUnit,
//     this.brand,
//     this.sku,
//     this.strength,
//   });

//   Medication copyWith({
//     String? id,
//     String? name,
//     String? description,
//     int? packageQuantity,
//     String? standardUnit,
//     String? picture,
//     String? form,
//     String? packageUnit,
//     String? brand,
//     String? sku,
//     String? strength,
//   }) {
//     return Medication(
//       id: id ?? this.id,
//       name: name ?? this.name,
//       description: description ?? this.description,
//       packageQuantity: packageQuantity ?? this.packageQuantity,
//       standardUnit: standardUnit ?? this.standardUnit,
//       picture: picture ?? this.picture,
//       form: form ?? this.form,
//       packageUnit: packageUnit ?? this.packageUnit,
//       brand: brand ?? this.brand,
//       sku: sku ?? this.sku,
//       strength: strength ?? this.strength,
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'description': description,
//       'packageQuantity': packageQuantity,
//       'standardUnit': standardUnit,
//       'picture': picture,
//       'form': form,
//       'packageUnit': packageUnit,
//       'brand': brand,
//       'sku': sku,
//       'strength': strength,
//     };
//   }

//   factory Medication.fromMap(Map<String, dynamic> map) {
//     return Medication(
//       id: map['id'] as String,
//       name: map['name'] as String,
//       description: map['description'] != null ? map['description'] as String : null,
//       packageQuantity: map['packageQuantity'] != null ? (map['packageQuantity'] as num).toInt() : null,
//       standardUnit: map['standardUnit'] != null ? map['standardUnit'] as String : null,
//       picture: map['picture'] != null ? map['picture'] as String : null,
//       form: map['form'] != null ? map['form'] as String : null,
//       packageUnit: map['packageUnit'] != null ? map['packageUnit'] as String : null,
//       brand: map['brand'] != null ? map['brand'] as String : null,
//       sku: map['sku'] != null ? map['sku'] as String : null,
//       strength: map['strength'] != null ? map['strength'] as String : null,
//     );
//   }

//   String toJson() => json.encode(toMap());

//   factory Medication.fromJson(String source) => Medication.fromMap(json.decode(source) as Map<String, dynamic>);

//   @override
//   String toString() {
//     return 'Medication(id: $id, name: $name, description: $description, packageQuantity: $packageQuantity, standardUnit: $standardUnit, picture: $picture, form: $form, packageUnit: $packageUnit, brand: $brand, sku: $sku, strength: $strength)';
//   }

//   @override
//   bool operator ==(Object other) {
//     if (identical(this, other)) return true;

//     return other is Medication &&
//         other.id == id &&
//         other.name == name &&
//         other.description == description &&
//         other.packageQuantity == packageQuantity &&
//         other.standardUnit == standardUnit &&
//         other.picture == picture &&
//         other.form == form &&
//         other.packageUnit == packageUnit &&
//         other.brand == brand &&
//         other.sku == sku &&
//         other.strength == strength;
//   }

//   @override
//   int get hashCode {
//     return id.hashCode ^
//         name.hashCode ^
//         (description?.hashCode ?? 0) ^
//         (packageQuantity?.hashCode ?? 0) ^
//         (standardUnit?.hashCode ?? 0) ^
//         (picture?.hashCode ?? 0) ^
//         (form?.hashCode ?? 0) ^
//         (packageUnit?.hashCode ?? 0) ^
//         (brand?.hashCode ?? 0) ^
//         (sku?.hashCode ?? 0) ^
//         (strength?.hashCode ?? 0);
//   }
// }
