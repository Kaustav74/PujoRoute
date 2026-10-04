import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/pujas_data.dart';
import '../services/voice_assistant_service.dart';
import '../screens/circuit_studio_screen.dart';
import '../screens/puja_calendar_screen.dart';

// Pujo Festive Theme Palette
const Color kMidnightBlue = Color(0xFF0D0D1E);
const Color kSindoorRed = Color(0xFFE62E2D);
const Color kMarigoldAmber = Color(0xFFFFB300);
const Color kTranslucentObsidian = Color(0xCC1C1C2E);

class VoiceAssistantDialog extends StatefulWidget {
  final double userLat;
  final double userLon;
  final VoidCallback? onEmergencyRequested;
  final Function(Pandal pandal)? onNavigateToPandal;

  const VoiceAssistantDialog({
    super.key,
    required this.userLat,
    required this.userLon,
    this.onEmergencyRequested,
    this.onNavigateToPandal,
  });

  static Future<void> show(
    BuildContext context, {
    required double userLat,
    required double userLon,
    VoidCallback? onEmergencyRequested,
    Function(Pandal pandal)? onNavigateToPandal,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => VoiceAssistantDialog(
        userLat: userLat,
        userLon: userLon,
        onEmergencyRequested: onEmergencyRequested,
        onNavigateToPandal: onNavigateToPandal,
      ),
    );
  }

  @override
  State<VoiceAssistantDialog> createState() => _VoiceAssistantDialogState();
}

class _VoiceAssistantDialogState extends State<VoiceAssistantDialog>
    with SingleTickerProviderStateMixin {
  final VoiceAssistantService _voiceService = VoiceAssistantService.instance;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  String _userSpeech = '';
  String _assistantText = 'Nomoshkar! 🙏 Speak your pandal destination, tithi query, or circuit request.';
  VoiceIntentResult? _resolvedIntent;
  bool _isListening = false;
  bool _isSpeaking = false;
  String? _statusMessage;

  final List<String> _suggestedPrompts = [
    'Take me to Sreebhumi',
    'Sandhi Puja timings 2026',
    'Plan 8 stops near me',
    'Emergency helpline pass',
    'Where is Ekdalia Evergreen?',
    'Maha Ashtami schedule',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _initAndStartListening();
  }

  Future<void> _initAndStartListening() async {
    await _voiceService.init();
    if (mounted) {
      _startListening();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _userSpeech = '';
      _statusMessage = 'Listening... Speak clearly';
    });

    try {
      await _voiceService.startListening(
        userLat: widget.userLat,
        userLon: widget.userLon,
        onResult: (partial) {
          if (mounted) {
            setState(() {
              _userSpeech = partial;
            });
          }
        },
        onIntentResolved: (intent) {
          if (mounted) {
            _handleIntentResolved(intent);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusMessage = 'Microphone ready. Tap orb to speak.';
        });
      }
    }
  }

  Future<void> _stopListening() async {
    await _voiceService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = 'Processing command...';
      });
      if (_userSpeech.trim().isNotEmpty && _resolvedIntent == null) {
        final intent = _voiceService.resolveVoiceIntent(
          _userSpeech,
          userLat: widget.userLat,
          userLon: widget.userLon,
        );
        _handleIntentResolved(intent);
      }
    }
  }

  void _handleIntentResolved(VoiceIntentResult intent) {
    setState(() {
      _isListening = false;
      _resolvedIntent = intent;
      _assistantText = intent.vocalResponse;
      _statusMessage = 'Intent detected: ${intent.type.name.toUpperCase()}';
      _isSpeaking = true;
    });

    // Speak the response aloud automatically
    _voiceService.speak(intent.vocalResponse).then((_) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });
  }

  void _onPromptChipTapped(String query) {
    setState(() {
      _userSpeech = query;
    });
    final intent = _voiceService.resolveVoiceIntent(
      query,
      userLat: widget.userLat,
      userLon: widget.userLon,
    );
    _handleIntentResolved(intent);
  }

  Future<void> _openGoogleMapsWalking(Pandal p) async {
    final bool hasUserLoc = widget.userLat != 0.0 && widget.userLon != 0.0;
    final destination = Uri.encodeComponent('${p.name}, Kolkata');
    final String urlString;
    if (hasUserLoc) {
      final origin = '${widget.userLat.toStringAsFixed(5)},${widget.userLon.toStringAsFixed(5)}';
      urlString = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=walking';
    } else {
      urlString = 'https://www.google.com/maps/search/?api=1&query=$destination';
    }
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  void _executeResolvedAction() {
    if (_resolvedIntent == null) return;

    final intent = _resolvedIntent!;
    switch (intent.type) {
      case VoiceIntentType.navigation:
        if (intent.targetPandal != null) {
          if (widget.onNavigateToPandal != null) {
            Navigator.pop(context);
            widget.onNavigateToPandal!(intent.targetPandal!);
          } else {
            _openGoogleMapsWalking(intent.targetPandal!);
          }
        }
        break;

      case VoiceIntentType.calendar:
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PujaCalendarScreen(
              userLat: widget.userLat,
              userLon: widget.userLon,
            ),
          ),
        );
        break;

      case VoiceIntentType.circuit:
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CircuitStudioScreen(
              userLat: widget.userLat,
              userLon: widget.userLon,
            ),
          ),
        );
        break;

      case VoiceIntentType.emergency:
        Navigator.pop(context);
        if (widget.onEmergencyRequested != null) {
          widget.onEmergencyRequested!();
        }
        break;

      case VoiceIntentType.general:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.76,
      decoration: BoxDecoration(
        color: kTranslucentObsidian,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(
          top: BorderSide(color: kSindoorRed, width: 2.5),
        ),
        boxShadow: [
          BoxShadow(
            color: kSindoorRed.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Title Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kSindoorRed.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: kSindoorRed.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.mic, color: kSindoorRed, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PujoRoute AI Voice Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        'Hands-Free Voice Intent Engine • Kolkata 2026',
                        style: TextStyle(color: kMarigoldAmber, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 16),

          // Main Scrollable Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Animated Voice Orb
                  _buildVoiceOrb(),

                  const SizedBox(height: 14),

                  // Status Indicator
                  Text(
                    _statusMessage ?? (_isListening ? 'Listening...' : 'Tap orb to speak'),
                    style: TextStyle(
                      color: _isListening ? kMarigoldAmber : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // User Spoken Transcript Bubble
                  if (_userSpeech.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF232338),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kMarigoldAmber.withOpacity(0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.record_voice_over, color: kMarigoldAmber, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '"$_userSpeech"',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // AI Response Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E1E34),
                          kSindoorRed.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _resolvedIntent != null
                            ? kMarigoldAmber.withOpacity(0.7)
                            : Colors.white12,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: kMarigoldAmber, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'AI Vocal Guidance',
                              style: TextStyle(
                                color: kMarigoldAmber,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            if (_isSpeaking)
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Vocalizing',
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _assistantText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),

                        // Action Button if intent resolved
                        if (_resolvedIntent != null &&
                            _resolvedIntent!.type != VoiceIntentType.general) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kSindoorRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              icon: Icon(_getActionIcon(_resolvedIntent!.type), size: 18),
                              label: Text(
                                _getActionLabel(_resolvedIntent!),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              onPressed: _executeResolvedAction,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Quick Voice Prompts
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'OR TRY SPEAKING:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedPrompts.map((p) {
                      return ActionChip(
                        label: Text(
                          p,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        backgroundColor: const Color(0xFF26263C),
                        side: BorderSide(color: Colors.white.withOpacity(0.12)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onPressed: () => _onPromptChipTapped(p),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: kMidnightBlue,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: Row(
              children: [
                // Stop audio button if speaking
                if (_isSpeaking)
                  IconButton(
                    icon: const Icon(Icons.volume_off, color: Colors.white70),
                    tooltip: 'Stop Audio',
                    onPressed: () {
                      _voiceService.stopSpeaking();
                      setState(() => _isSpeaking = false);
                    },
                  ),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.redAccent.shade700 : const Color(0xFF2A2A44),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: _isListening ? kSindoorRed : kMarigoldAmber.withOpacity(0.4),
                        ),
                      ),
                    ),
                    icon: Icon(
                      _isListening ? Icons.stop_circle_outlined : Icons.mic,
                      color: _isListening ? Colors.white : kMarigoldAmber,
                      size: 20,
                    ),
                    label: Text(
                      _isListening ? 'Stop Listening' : 'Tap to Speak',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _isListening ? _stopListening : _startListening,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceOrb() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _isListening ? _pulseAnimation.value : 1.0;
        final auraOpacity = _isListening ? 0.45 : (_isSpeaking ? 0.35 : 0.2);

        return GestureDetector(
          onTap: () {
            if (_isListening) {
              _stopListening();
            } else {
              _startListening();
            }
          },
          child: SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Pulsing Glow Wave 1
                Transform.scale(
                  scale: scale * 1.18,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kSindoorRed.withOpacity(auraOpacity * 0.5),
                    ),
                  ),
                ),
                // Outer Pulsing Glow Wave 2
                Transform.scale(
                  scale: scale * 1.08,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kMarigoldAmber.withOpacity(auraOpacity),
                    ),
                  ),
                ),
                // Inner Glowing Core Orb
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isListening
                          ? [kSindoorRed, const Color(0xFFFF5252)]
                          : (_isSpeaking
                              ? [kMarigoldAmber, const Color(0xFFFF9100)]
                              : [const Color(0xFF333355), const Color(0xFF222238)]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? kSindoorRed : kMarigoldAmber).withOpacity(0.6),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.mic
                        : (_isSpeaking ? Icons.graphic_eq : Icons.mic_none),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getActionIcon(VoiceIntentType type) {
    switch (type) {
      case VoiceIntentType.navigation:
        return Icons.navigation_rounded;
      case VoiceIntentType.calendar:
        return Icons.calendar_month_rounded;
      case VoiceIntentType.circuit:
        return Icons.alt_route_rounded;
      case VoiceIntentType.emergency:
        return Icons.shield_outlined;
      case VoiceIntentType.general:
        return Icons.auto_awesome;
    }
  }

  String _getActionLabel(VoiceIntentResult intent) {
    switch (intent.type) {
      case VoiceIntentType.navigation:
        return intent.targetPandal != null
            ? 'Open Google Maps to ${intent.targetPandal!.name}'
            : 'Open Walking Directions';
      case VoiceIntentType.calendar:
        return 'View 2026 Puja Calendar & Tithis';
      case VoiceIntentType.circuit:
        return 'Open ${intent.stopCount}-Stop Circuit Studio';
      case VoiceIntentType.emergency:
        return 'Open Emergency Helplines Pass';
      case VoiceIntentType.general:
        return 'Explore Options';
    }
  }
}
