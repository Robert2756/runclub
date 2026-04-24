import 'package:flutter/material.dart';
import 'services/image_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/app_bar.dart';

final supabase = Supabase.instance.client;
final imageService = ImageService();

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.title});
  final String title;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        // title: widget.title,
        actions: [
        ],
      ),
    );
  }
}