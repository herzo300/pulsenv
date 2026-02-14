// lib/widgets/complaint_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeleton_loader/skeleton_loader.dart';

class ComplaintListWidget extends StatelessWidget {
  final bool isLoading;
  final List complaints;

  const ComplaintListWidget({
    super.key,
    required this.isLoading,
    required this.complaints,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SkeletonLoader(
        builder: Container(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.white, radius: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Container(height: 20, color: Colors.white),
              ),
            ],
          ),
        ),
        items: 6,
        period: const Duration(seconds: 2),
      );
    }

    return ListView.builder(
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        final item = complaints[index];
        final category = item['category'] ?? 'Категория';
        final address = item['address'] ?? 'Адрес уточняется';
        final summary = item['summary'] ?? '';

        return Slidable(
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (context) {
                  Share.share(
                    'Жалоба в Нижневартовске:\n$summary\nАдрес: $address',
                  );
                },
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: Icons.share,
                label: 'Поделиться',
              ),
            ],
          ),
          child: ListTile(
            leading: SizedBox(
              width: 50,
              height: 50,
              child: Lottie.asset(
                'assets/animations/alert.json',
                repeat: true,
              ),
            ),
            title: Text(category),
            subtitle: Text(address),
          ),
        );
      },
    );
  }
}
