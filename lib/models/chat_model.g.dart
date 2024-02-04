// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
      userEmail: json['userEmail'] as String,
      messageContent: json['messageContent'] as String,
      messageType: json['messageType'] as String,
    );

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'messageContent': instance.messageContent,
      'messageType': instance.messageType,
      'userEmail': instance.userEmail,
    };
