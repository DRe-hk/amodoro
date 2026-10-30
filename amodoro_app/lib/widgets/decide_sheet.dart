import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import 'flat_avatar.dart';

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
      _statusMessage = 'Girando la ruleta entre sus pendientes...';
    });
    try {
      await Future.delayed(const Duration(milliseconds: 550));
      await widget.api.spinRoulette();
      await widget.onRefresh();
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = 'La ruleta ha elegido una actividad.';
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
            _statusMessage = 'Hubo coincidencia única. Tenemos ganadora.';
          } else if (status == 'tie_next_round') {
            _statusMessage =
                'Hubo empate. Se inició automáticamente una nueva ronda de desempate sin mostrar resultados parciales.';
          } else {
            _statusMessage =
                'Votos guardados en secreto. Esperando a tu pareja.';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).scaffoldBackgroundColor;
    final cardSurface =
        isDark ? const Color(0xFF1F2421) : const Color(0xFFF4EFE8);
    final coralBg =
        isDark ? AmodoroTheme.coralPillDark : AmodoroTheme.coralPillLight;
    final coralInk = isDark
        ? AmodoroTheme.coralPillTextDark
        : AmodoroTheme.coralPillTextLight;

    final voting = widget.sync.activeVoting;
    final winner = widget.sync.latestResolved?.winner;

    return DraggableScrollableSheet(
      initialChildSize: 0.84,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          decoration: AmodoroTheme.floatingPerspectiveBox(
            color: surface,
            radius: 30,
            thickness: 2.5,
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DECIDIR EN PAREJA',
                    style: TextStyle(fontSize: 12, letterSpacing: 1.5),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: AmodoroTheme.sysIcon(Symbols.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (winner != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AmodoroTheme.floatingPerspectiveBox(
                    color: AmodoroTheme.parseHexColor(winner.bgColor),
                    radius: 24,
                    thickness: 2.5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVIDAD ELEGIDA (${widget.sync.latestResolved?.mode == 'roulette' ? 'RULETA' : 'RONDA #${widget.sync.latestResolved?.roundNumber ?? 1}'})',
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: Color(0xFF1F1B18),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        winner.title,
                        style: const TextStyle(
                          fontSize: 19,
                          color: Color(0xFF1F1B18),
                        ),
                      ),
                      if (winner.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          winner.notes,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF4E453E),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Pestañas en perspectiva: RULETA vs VOTACIÓN 4-5
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = 0),
                      child: Container(
                        height: 42,
                        decoration: AmodoroTheme.floatingPerspectiveBox(
                          color: _tab == 0 ? coralBg : cardSurface,
                          radius: 999,
                          thickness: 2.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AmodoroTheme.sysIcon(
                              Symbols.casino,
                              size: 18,
                              color: _tab == 0 ? coralInk : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'RULETA',
                              style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 1.3,
                                color: _tab == 0 ? coralInk : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = 1),
                      child: Container(
                        height: 42,
                        decoration: AmodoroTheme.floatingPerspectiveBox(
                          color: _tab == 1 ? coralBg : cardSurface,
                          radius: 999,
                          thickness: 2.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AmodoroTheme.sysIcon(
                              Symbols.how_to_vote,
                              size: 18,
                              color: _tab == 1 ? coralInk : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'VOTACIÓN 4–5',
                              style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 1.3,
                                color: _tab == 1 ? coralInk : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: AmodoroTheme.floatingPerspectiveBox(
                    color: const Color(0xFFFFDAD6),
                    radius: 16,
                    thickness: 2.0,
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF3B0D09),
                    ),
                  ),
                ),
              ],

              if (_tab == 0) ...[
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: AmodoroTheme.floatingPerspectiveBox(
                    color: cardSurface,
                    radius: 26,
                    thickness: 2.5,
                  ),
                  child: Column(
                    children: [
                      AmodoroTheme.sysIcon(Symbols.casino, size: 42),
                      const SizedBox(height: 12),
                      const Text(
                        'Elige inmediatamente 1 actividad al azar de su tablero de PENDIENTES.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: _busy ? null : _spinRoulette,
                        child: Container(
                          height: 46,
                          decoration: AmodoroTheme.floatingPerspectiveBox(
                            color: coralBg,
                            radius: 999,
                            thickness: 2.5,
                          ),
                          child: Center(
                            child: Text(
                              _busy ? 'GIRANDO...' : 'GIRAR RULETA AHORA',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.5,
                                color: coralInk,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AmodoroTheme.floatingPerspectiveBox(
                    color: cardSurface,
                    radius: 26,
                    thickness: 2.5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Se eligen 4 o 5 pendientes al azar. Cada uno marca Sí o No en secreto. Si coinciden en una sola, gana; si hay empate, pasa automáticamente a otra ronda sin mostrar resultados parciales.',
                        style: TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      if (voting == null) ...[
                        GestureDetector(
                          onTap: _busy ? null : _startVoting,
                          child: Container(
                            height: 46,
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: coralBg,
                              radius: 999,
                              thickness: 2.5,
                            ),
                            child: Center(
                              child: Text(
                                'INICIAR VOTACIÓN DE 4–5 AL AZAR',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  letterSpacing: 1.4,
                                  color: coralInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else if (voting.myVoteSubmitted) ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: AmodoroTheme.floatingPerspectiveBox(
                            color: const Color(0xFFE8DEF8),
                            radius: 22,
                            thickness: 2.0,
                          ),
                          child: Column(
                            children: [
                              AmodoroTheme.sysIcon(
                                Symbols.lock,
                                size: 32,
                                color: const Color(0xFF1F1B18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'RONDA #${voting.roundNumber} · VOTO SECRETO ENVIADO',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF1F1B18),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Esperando a tu pareja. Los resultados parciales están ocultos.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF4E453E),
                                ),
                              ),
                              const SizedBox(height: 14),
                              GestureDetector(
                                onTap: widget.onRefresh,
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  decoration:
                                      AmodoroTheme.floatingPerspectiveBox(
                                    color: const Color(0xFFFCF9F5),
                                    radius: 999,
                                    thickness: 2.0,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'ACTUALIZAR ESTADO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 1.2,
                                        color: Color(0xFF1F1B18),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          'RONDA #${voting.roundNumber} · MARCA SÍ O NO:',
                          style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...voting.candidates.map((c) {
                          final currentVote = _votes[c.id] ?? true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: AmodoroTheme.parseHexColor(c.bgColor),
                              radius: 18,
                              thickness: 2.0,
                            ),
                            child: Row(
                              children: [
                                FlatAvatarBadge(
                                  avatarId: c.authorAvatarId,
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF1F1B18),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _votes[c.id] = !currentVote;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration:
                                        AmodoroTheme.floatingPerspectiveBox(
                                      color: currentVote
                                          ? coralBg
                                          : const Color(0xFFFCF9F5),
                                      radius: 999,
                                      thickness: 2.0,
                                    ),
                                    child: Text(
                                      currentVote ? 'SÍ' : 'NO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 1.2,
                                        color: currentVote
                                            ? coralInk
                                            : const Color(0xFF1F1B18),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _busy ? null : () => _submitVotes(voting),
                          child: Container(
                            height: 46,
                            decoration: AmodoroTheme.floatingPerspectiveBox(
                              color: coralBg,
                              radius: 999,
                              thickness: 2.5,
                            ),
                            child: Center(
                              child: Text(
                                _busy
                                    ? 'ENVIANDO...'
                                    : 'ENVIAR MIS VOTOS EN SECRETO',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  letterSpacing: 1.4,
                                  color: coralInk,
                                ),
                              ),
                            ),
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
