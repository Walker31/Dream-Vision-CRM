import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../../models/follow_up_model.dart';
import '../../services/enquiry_service.dart';
import '../../widgets/back_button.dart';
import '../../models/enquiry_model.dart';
import '../Telecaller/follow_up_sheet.dart';
import '../../providers/auth_provider.dart';

class FollowUpPage extends StatefulWidget {
  final int enquiryId;
  final String enquiryName;

  const FollowUpPage({
    super.key,
    required this.enquiryId,
    required this.enquiryName,
  });

  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  final EnquiryService _service = EnquiryService();
  late Future<List<FollowUp>> _followUps;
  Logger logger = Logger();

  @override
  void initState() {
    super.initState();
    _loadFollowUps();
  }

  void _loadFollowUps() {
    _followUps = _service.getFollowUpsForEnquiry(widget.enquiryId).then((list) {
      try {
        return list
            .whereType<Map>() // avoid backend returning strings
            .map((e) => FollowUp.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (err) {
        throw Exception("Invalid follow-up data: $err");
      }
    });
  }

  Future<void> _openEditor(FollowUp followUp) async {
    try {
      final enquiryData = await _service.getEnquiryById(widget.enquiryId);
      final enquiry = Enquiry.fromJson(enquiryData);

      if (!mounted) return;

      final result = await showModalBottomSheet<bool?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            AddFollowUpSheet(enquiry: enquiry, existingFollowUp: followUp),
      );

      if (mounted && result == true) {
        setState(() => _loadFollowUps());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to open editor: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        leading: const BackButtonIos(),
        title: const Text('Follow-up History'),
      ),
      body: FutureBuilder<List<FollowUp>>(
        future: _followUps,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load follow-ups:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error),
                ),
              ),
            );
          }

          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return Center(
              child: Text(
                'No follow-ups recorded yet.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) {
              return _TimelineTile(
                followUp: data[index],
                isFirst: index == 0,
                isLast: index == data.length - 1,
                onEdit: () => _openEditor(data[index]),
              );
            },
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TILE WITH ANIMATIONS
// -----------------------------------------------------------------------------

class _TimelineTile extends StatefulWidget {
  final FollowUp followUp;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;

  const _TimelineTile({
    required this.followUp,
    required this.onEdit,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<_TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<_TimelineTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _dotScale;
  Logger logger = Logger();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Small stagger effect
    Future.delayed(Duration(milliseconds: widget.isFirst ? 0 : 80), () {
      if (mounted) _controller.forward();
    });

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.20),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _dotScale = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final currentUserId = auth.user?.profileId;
    final currentUserRole = auth.user?.role;
    final followUpOwnerId = widget.followUp.user?.id;

    final bool canEdit =
        currentUserRole == 'Admin' || currentUserId == followUpOwnerId;

    final time = widget.followUp.timestamp.toLocal();

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConnector(context),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Material(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onLongPress: canEdit ? widget.onEdit : null,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // DATE + Edit button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat.yMMMd().add_jm().format(time),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: widget.isFirst
                                        ? cs.primary
                                        : cs.onSurface,
                                    fontSize: 16,
                                  ),
                                ),
                                if (canEdit)
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: cs.primary,
                                    ),
                                    onPressed: widget.onEdit,
                                  ),
                              ],
                            ),

                            Divider(color: cs.outlineVariant),

                            _info(
                              context,
                              icon: Icons.person_outline,
                              label: "By:",
                              value: widget.followUp.user?.fullName ?? "N/A",
                            ),

                            const SizedBox(height: 8),

                            _status(context),

                            const SizedBox(height: 12),

                            Text(
                              widget.followUp.remarks,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),

                            if (widget.followUp.nextFollowUpDate != null &&
                                widget.followUp.nextFollowUpDate!
                                    .trim()
                                    .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _nextFollowUp(context),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: Container(
            width: 2,
            color: widget.isFirst ? Colors.transparent : cs.outlineVariant,
          ),
        ),

        // Animated Dot
        ScaleTransition(
          scale: _dotScale,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isFirst ? cs.primary : cs.outline,
            ),
          ),
        ),

        Expanded(
          child: Container(
            width: 2,
            color: widget.isLast ? Colors.transparent : cs.outlineVariant,
          ),
        ),
      ],
    );
  }

  Widget _status(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final before = widget.followUp.statusBeforeFollowUpName;
    final after = widget.followUp.statusAfterFollowUpName;

    if (after == null) {
      return _info(
        context,
        icon: Icons.flag_outlined,
        label: "Status:",
        value: "Not recorded",
        valueColor: cs.onSurfaceVariant,
      );
    }

    if (before == after) {
      return _info(
        context,
        icon: Icons.flag_outlined,
        label: "Status:",
        value: "Kept as '$after'",
      );
    }

    if (before == null) {
      return _info(
        context,
        icon: Icons.flag_outlined,
        label: "Status:",
        value: "Set to '$after'",
        valueColor: cs.primary,
      );
    }

    return Row(
      children: [
        Icon(
          Icons.change_history_outlined,
          size: 16,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          "Status:",
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: before,
                  style: const TextStyle(
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                TextSpan(
                  text: "  ➜  ",
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: after,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _nextFollowUp(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    DateTime? date;
    try {
      date = DateTime.parse(widget.followUp.nextFollowUpDate!).toLocal();
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.event_repeat_outlined, size: 20, color: cs.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Next Follow-up: ${DateFormat.yMMMd().add_jm().format(date)}",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
