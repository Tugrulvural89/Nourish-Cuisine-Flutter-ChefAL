import 'package:json_annotation/json_annotation.dart';
part 'chat_model.g.dart';
@JsonSerializable()
class ChatMessage{
  String messageContent;
  String messageType;
  String userEmail;
  ChatMessage({
    required this.userEmail, required this.messageContent,
    required this.messageType,}
      );
  /// Connect the generated [_$PersonFromJson] function to the `fromJson`
  /// factory.
  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
        _$ChatMessageFromJson(json);

  /// Connect the generated [_$PersonToJson] function to the `toJson` method.
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);


}