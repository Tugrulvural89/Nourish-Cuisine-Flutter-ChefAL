import 'package:nourish/generated/json/base/json_convert_content.dart';
import 'package:nourish/models/chat_model.dart';
import 'package:json_annotation/json_annotation.dart';


ChatMessage $ChatMessageFromJson(Map<String, dynamic> json) {
  final ChatMessage chatMessage = ChatMessage();
  final String? messageContent = jsonConvert.convert<String>(
      json['messageContent']);
  if (messageContent != null) {
    chatMessage.messageContent = messageContent;
  }
  final String? messageType = jsonConvert.convert<String>(json['messageType']);
  if (messageType != null) {
    chatMessage.messageType = messageType;
  }
  final String? userEmail = jsonConvert.convert<String>(json['userEmail']);
  if (userEmail != null) {
    chatMessage.userEmail = userEmail;
  }
  return chatMessage;
}

Map<String, dynamic> $ChatMessageToJson(ChatMessage entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['messageContent'] = entity.messageContent;
  data['messageType'] = entity.messageType;
  data['userEmail'] = entity.userEmail;
  return data;
}

extension ChatMessageExtension on ChatMessage {
  ChatMessage copyWith({
    String? messageContent,
    String? messageType,
    String? userEmail,
  }) {
    return ChatMessage()
      ..messageContent = messageContent ?? this.messageContent
      ..messageType = messageType ?? this.messageType
      ..userEmail = userEmail ?? this.userEmail;
  }
}