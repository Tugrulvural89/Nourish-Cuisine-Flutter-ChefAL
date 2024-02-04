import 'package:nourish/generated/json/base/json_convert_content.dart';
import 'package:nourish/models/food_item.dart';
import 'package:json_annotation/json_annotation.dart';


FoodItem $FoodItemFromJson(Map<String, dynamic> json) {
  final FoodItem foodItem = FoodItem();
  final String? label = jsonConvert.convert<String>(json['label']);
  if (label != null) {
    foodItem.label = label;
  }
  final String? image = jsonConvert.convert<String>(json['image']);
  if (image != null) {
    foodItem.image = image;
  }
  final String? uri = jsonConvert.convert<String>(json['uri']);
  if (uri != null) {
    foodItem.uri = uri;
  }
  return foodItem;
}

Map<String, dynamic> $FoodItemToJson(FoodItem entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['label'] = entity.label;
  data['image'] = entity.image;
  data['uri'] = entity.uri;
  return data;
}

extension FoodItemExtension on FoodItem {
  FoodItem copyWith({
    String? label,
    String? image,
    String? uri,
  }) {
    return FoodItem()
      ..label = label ?? this.label
      ..image = image ?? this.image
      ..uri = uri ?? this.uri;
  }
}