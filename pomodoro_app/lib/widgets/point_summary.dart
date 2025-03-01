// widgets/point_summary.dart - ポイント表示ウィジェット
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_restriction_provider.dart';
import '../screens/app_store_screen.dart';

class PointSummary extends StatelessWidget {
  const PointSummary({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appRestrictionProvider = Provider.of<AppRestrictionProvider>(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'アプリポイント',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_bag),
                  onPressed: () {
                    // アプリストアに遷移（インデックスを3に設定）
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const AppStoreScreen(),
                    ));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.stars,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${appRestrictionProvider.availablePoints} pt',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Text('利用可能ポイント'),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_bag),
                  label: const Text('アプリストア'),
                  onPressed: () {
                    // アプリストアに遷移
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const AppStoreScreen(),
                    ));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
