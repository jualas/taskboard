// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppData _$AppDataFromJson(Map<String, dynamic> json) => AppData(
  projects: (json['projects'] as List<dynamic>)
      .map((e) => Project.fromJson(e as Map<String, dynamic>))
      .toList(),
  tasks: (json['tasks'] as List<dynamic>)
      .map((e) => Task.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AppDataToJson(AppData instance) => <String, dynamic>{
  'projects': instance.projects,
  'tasks': instance.tasks,
};
