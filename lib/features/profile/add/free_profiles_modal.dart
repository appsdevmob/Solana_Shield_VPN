import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';

import 'package:hiddify/features/profile/add/widgets/free_btns.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

class FreeProfilesModal extends HookConsumerWidget {
  const FreeProfilesModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final scrollController = ScrollController();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.common.free, style: Theme.of(context).textTheme.titleLarge),
                IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
              ],
            ),
          ),
          Flexible(child: FreeBtns(scrollController: scrollController)),
        ],
      ),
    );
  }
}
