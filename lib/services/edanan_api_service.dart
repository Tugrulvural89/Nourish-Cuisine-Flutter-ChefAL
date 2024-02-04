import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/food_item.dart';

class ApiService {
  Dio dio = Dio();
  Future<List<FoodItem>> fetchRandomFoods() async {
    await dotenv.load();
    var appKey = dotenv.get('EDANAMAPIKEY'); //replace with your App ID
    var appId = dotenv.get('EDANAMAPIID'); //replace with your App Key
    var baseUrl =
        'https://api.edamam.com/api/recipes/v2?'
        'type=public&app_id=$appId&app_key=$appKey&ingr=10&random'
        '=true&imageSize=LARGE';
    // No cached data found, fetch new data
    final response = await dio.get(baseUrl);
    if (response.statusCode == 200) {
      var data = response.data['hits'] as List;
      var foodItems =
          data.map((food) => FoodItem.fromJson(food['recipe'])).toList();
      return foodItems;
    } else {
      throw Exception('Failed to load food items, please try again');
    }
  }
}
