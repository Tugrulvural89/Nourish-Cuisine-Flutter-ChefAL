import 'package:json_annotation/json_annotation.dart';

part 'food_item.g.dart';

@JsonSerializable()
class FoodItem {
  final String label;
  final String image;
  final String uri;

  FoodItem({required this.label, required this.image, required this.uri});

  factory FoodItem.fromJson(Map<String, dynamic> json)
  => _$FoodItemFromJson(json);
  Map<String, dynamic> toJson() => _$FoodItemToJson(this);
}
