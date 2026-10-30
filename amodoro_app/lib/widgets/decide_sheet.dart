import 'package:flutter/material.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';

class DecideSheet extends StatefulWidget {
  final SyncPayload sync;
  final AmodoroApiClient api;
  final Future<void> Function() onRefresh;

  const DecideSheet({
    super.key,
    required this.sync,
    required this.api,
    required this.onRefresh,
  });

  @override
  State<DecideSheet> createState() => _DecideSheetState();
}

class _DecideSheetState extends State<DecideSheet> {
  int _tab = 0; // 0: Ruleta, 1: Votación 4-5
  bool _busy = false;
  String? _statusMessage;
  final Map<String, bool> _votes = {};

  @override
  void initState() {
    super.initState();
    if (widget.sync.activeVoting != null) {
      _tab = 1;
      for (final c in widget.sync.activeVoting!.candidates) {
        _votes[c.id] = true;
      }
    }
  }

  Future<void> _spinRoulette() async {
    setState(() {
      _busy = true;
      _statusMessage = 'Girando la ruleta entre sus Actividades... 🎡';
    });
    try {
      await Future.delayed(const Duration(milliseconds: 650));
      await widget.api.spinRoulette();
      await widget.onRefresh();
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = '¡La ruleta ha elegido una actividad!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _startVoting() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await widget.api.startVoting();
      await widget.onRefresh();
      if (mounted) {
        setState(() {
          _busy = false;
          _tab = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submitVotes(ActiveVotingState voting) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final votePayload = <String, bool>{};
      for (final c in voting.candidates) {
        votePayload[c.id] = _votes[c.id] ?? false;
      }
      final res = await widget.api.submitVotes(voting.sessionId, votePayload);
      await widget.onRefresh();
      if (mounted) {
        final status = res['status']?.toString() ?? '';
        setState(() {
          _busy = false;
          if (status == 'resolved') {
            _statusMessage = '🎉 ¡Hubo coincidencia única! Tenemos ganadora.';
          } else if (status == 'tie_next_round') {
            _statusMessage =
                '⚖️ Hubo empate. Se inició automáticamente una nueva ronda de desempate sin mostrar resultados parciales.';
          } else {
            _statusMessage =
                '🔒 Votos guardados en secreto. Esperando a tu pareja.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final voting = widget.sync.activeVoting;
    final winner = widget.sync.latestResolved?.winner;

    return DraggableScrollableSheet(
      initialChildSize: 0.84,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '🎲 DECIDIR EN PAREJA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Elige por Ruleta al azar o Votación ciega de 4–5 actividades',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),

              // Ganadora reciente
              if (winner != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AmodoroTheme.parseHexColor(winner.bgColor),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🏆 ÚLTIMA ACTIVIDAD ELEGIDA (${widget.sync.latestResolved?.mode == 'roulette' ? 'RULETA' : 'VOTACIÓN RONDA #${widget.sync.latestResolved?.roundNumber ?? 1}'})',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: AmodoroTheme.getContrastingInk(
                            AmodoroTheme.parseHexColor(winner.bgColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${winner.emoji} ${winner.title}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AmodoroTheme.getContrastingInk(
                            AmodoroTheme.parseHexColor(winner.bgColor),
                          ),
                        ),
                      ),
                      if (winner.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          winner.notes,
                          style: TextStyle(
                            fontSize: 13,
                            color: AmodoroTheme.getContrastingMutedInk(
                              AmodoroTheme.parseHexColor(winner.bgColor),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Pestañas: Ruleta vs Votación 4-5
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('🎡 Ruleta al azar'),
                      selected: _tab == 0,
                      onSelected: (_) => setState(() => _tab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('🗳️ Votación (4-5)'),
                      selected: _tab == 1,
                      onSelected: (_) => setState(() => _tab = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AmodoroTheme.coralPillLight.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],

              if (_tab == 0) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Text('🎡', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 8),
                      const Text(
                        'Ruleta Instantánea',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Selecciona inmediatamente 1 actividad al azar de su tablero compartido de Actividades.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AmodoroTheme.coralPillLight,
                          foregroundColor: AmodoroTheme.coralPillTextLight,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _busy ? null : _spinRoulette,
                        icon: const Icon(Icons.casino_rounded),
                        label: Text(
                          _busy ? 'Girando...' : 'Girar la Ruleta Ahora',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Votación Ciega de 4 o 5 Actividades',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Se toman 4 o 5 actividades al azar. Cada uno vota Sí o No en secreto. Si coinciden en una sola, gana; si hay empate, pasa automáticamente a otra ronda sin mostrar resultados parciales.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 14),
                      if (voting == null) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AmodoroTheme.coralPillLight,
                            foregroundColor: AmodoroTheme.coralPillTextLight,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _busy ? null : _startVoting,
                          icon: const Icon(Icons.how_to_vote_rounded),
                          label: const Text(
                            'Iniciar Votación de 4–5 al azar',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ] else if (voting.myVoteSubmitted) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8DEF8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text('🔒', style: TextStyle(fontSize: 32)),
                              const SizedBox(height: 6),
                              Text(
                                'Ronda #${voting.roundNumber} · Voto secreto enviado',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1F1B18),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Esperando a que tu pareja termine de votar. Los resultados parciales están ocultos.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF4E453E),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: widget.onRefresh,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Comprobar si ya votó'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          'RONDA #${voting.roundNumber} · VOTA SÍ O NO EN SECRETO:',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...voting.candidates.map((c) {
                          final currentVote = _votes[c.id] ?? true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AmodoroTheme.parseHexColor(c.bgColor),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Text(c.emoji,
                                    style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1F1B18),
                                        ),
                                      ),
                                      Text(
                                        'Por: ${c.authorLabel}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF4E453E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                        value: true, label: Text('Sí')),
                                    ButtonSegment(
                                        value: false, label: Text('No')),
                                  ],
                                  selected: {currentVote},
                                  onSelectionChanged: (s) {
                                    setState(() {
                                      _votes[c.id] = s.first;
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AmodoroTheme.coralPillLight,
                            foregroundColor: AmodoroTheme.coralPillTextLight,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed:
                              _busy ? null : () => _submitVotes(voting),
                          icon: const Icon(Icons.lock_outline_rounded),
                          label: Text(
                            _busy
                                ? 'Enviando...'
                                : 'Enviar mis votos en secreto',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
