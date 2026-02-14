// lib/models/complaint.dart
import 'package:flutter/material.dart';

/// Модель жалобы
class Complaint {
  final int id;
  final String title;
  final String description;
  final String category;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String status;
  final String? createdAt;
  final String? source;

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.latitude,
    this.longitude,
    this.address,
    required this.status,
    this.createdAt,
    this.source,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'Прочее',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      address: json['address'],
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'],
      source: json['source'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': status,
      'created_at': createdAt,
      'source': source,
    };
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'В обработке';
      case 'in_progress':
        return 'В работе';
      case 'resolved':
        return 'Решено';
      case 'rejected':
        return 'Отклонено';
      default:
        return 'Неизвестно';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
