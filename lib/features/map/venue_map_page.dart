import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';
import '../../models/venue_location.dart';
import '../../services/schedule_repository.dart';

const _mapAsset = AssetImage('assets/images/venue-map.png');

class VenueMapPage extends ConsumerWidget {
  const VenueMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(venueLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Venue Map')),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Map unavailable: $e')),
        data: (locations) => _MapBody(locations: locations),
      ),
    );
  }
}

class _MapBody extends ConsumerStatefulWidget {
  final List<VenueLocation> locations;
  const _MapBody({required this.locations});

  @override
  ConsumerState<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends ConsumerState<_MapBody> {
  Size? _imageSize;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _stream = _mapAsset.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _imageSize = Size(info.image.width.toDouble(),
            info.image.height.toDouble());
      });
    }, onError: (e, _) {
      if (mounted) setState(() => _imageSize = const Size(1500, 1150));
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final imageRatio = _imageSize!.width / _imageSize!.height;

    return InteractiveViewer(
      maxScale: 6,
      minScale: 1.0,
      child: LayoutBuilder(builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;
        final containerRatio = cw / ch;

        double w, h, dx, dy;
        if (containerRatio > imageRatio) {
          // container is wider than image: fit height, letterbox horizontally
          h = ch;
          w = h * imageRatio;
          dx = (cw - w) / 2;
          dy = 0;
        } else {
          // container is narrower: fit width, letterbox vertically
          w = cw;
          h = w / imageRatio;
          dx = 0;
          dy = (ch - h) / 2;
        }

        return Stack(children: [
          Positioned(
            left: dx,
            top: dy,
            width: w,
            height: h,
            child: const Image(image: _mapAsset, fit: BoxFit.fill),
          ),
          for (final loc in widget.locations)
            Positioned(
              left: dx + loc.rect.x * w,
              top: dy + loc.rect.y * h,
              width: loc.rect.w * w,
              height: loc.rect.h * h,
              child: Tooltip(
                message: loc.displayName,
                preferBelow: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showEventsForLocation(context, ref, loc),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2D5E3E).withValues(alpha: 0.22),
                      border: Border.all(
                          color:
                              const Color(0xFF2D5E3E).withValues(alpha: 0.85),
                          width: 2),
                    ),
                  ),
                ),
              ),
            ),
        ]);
      }),
    );
  }

  void _showEventsForLocation(
      BuildContext context, WidgetRef ref, VenueLocation loc) {
    final all = ref.read(scheduleRepositoryProvider).events;
    final atLoc = all.where((e) => e.locationKey == loc.key).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    showModalBottomSheet(
      context: context,
      builder: (_) => _LocationEventsSheet(location: loc, events: atLoc),
    );
  }
}

class _LocationEventsSheet extends StatelessWidget {
  final VenueLocation location;
  final List<Event> events;
  const _LocationEventsSheet({required this.location, required this.events});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE h:mm a');
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(location.displayName,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text('No events scheduled here yet.'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: events.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  title: Text(events[i].title),
                  subtitle: Text(fmt.format(events[i].startTime)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
