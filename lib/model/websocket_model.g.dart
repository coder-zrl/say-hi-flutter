// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'websocket_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestClientInfo _$RequestClientInfoFromJson(Map<String, dynamic> json) =>
    RequestClientInfo(
      userId: json['userId'] as String,
      appVersion: json['appVersion'] as String,
    );

Map<String, dynamic> _$RequestClientInfoToJson(RequestClientInfo instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'appVersion': instance.appVersion,
    };

LongLinkBody _$LongLinkBodyFromJson(Map<String, dynamic> json) => LongLinkBody(
  requestClientInfo: json['requestClientInfo'] == null
      ? null
      : RequestClientInfo.fromJson(
          json['requestClientInfo'] as Map<String, dynamic>,
        ),
  command: json['command'] as String,
  data: json['data'] as String,
);

Map<String, dynamic> _$LongLinkBodyToJson(LongLinkBody instance) =>
    <String, dynamic>{
      'requestClientInfo': instance.requestClientInfo,
      'command': instance.command,
      'data': instance.data,
    };
