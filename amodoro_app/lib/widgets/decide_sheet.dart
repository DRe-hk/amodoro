import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/amodoro_models.dart';
import '../services/api_client.dart';
import '../theme/amodoro_theme.dart';
import 'flat_avatar.dart';
import 'pressable_button.dart';

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
          decoration: AmodoroTheme.cardOutlineBox(
            color: surface,
            radius: 30,
            borderColor: isDark ? const Color(0xFF383232) : const Color(0xFFE2DAD0),
            borderWidth: 2.5,
            subtleShadow: false,
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DECIDIR EN PAREJA',
                    style: AmodoroTheme.googleSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : AmodoroTheme.lightInk,
                    ),
                  ),
                  AmodoroPressableButton(
                    onTap: () => Navigator.of(context).pop(),
                    color: isDark
                        ? AmodoroTheme.darkContainer
                        : const Color(0xFFF0ECE4),
                    lipColor: isDark
                        ? const Color(0xFF181515)
                        : const Color(0xFFDCD6CE),
                    lipHeight: 3.5,
                    radius: 999,
                    width: 38,
                    height: 38,
                    child: Center(
                      child: AmodoroTheme.sysIcon(
                        Symbols.close,
                        size: 18,
                        color: isDark ? Colors.white : AmodoroTheme.lightInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (winner != null) ...[
                Builder(
                  builder: (_) {
                    final winnerColor =
                        AmodoroTheme.parseHexColor(winner.bgColor);
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AmodoroTheme.cardOutlineBox(
                        color: winnerColor,
                        radius: 24,
                        borderColor:
                            AmodoroTheme.darkenForPerspective(winnerColor, 0.16),
                        borderWidth: 2.0,
                        subtleShadow: false,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ACTIVIDAD ELEGIDA (${widget.sync.latestResolved?.mode == 'roulette' ? 'RULETA' : 'RONDA #${widget.sync.latestResolved?.roundNumber ?? 1}'})',
                            style: AmodoroTheme.googleSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: const Color(0xFF1F1B18),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            winner.title,
                            style: AmodoroTheme.googleSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F1B18),
                            ),
                          ),
                          if (winner.notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              winner.notes,
                              style: AmodoroTheme.googleSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4E453E),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Pestañas: RULETA AL AZAR vs VOTAR JUNTOS (AmodoroPressableButton con lipHeight: 3.5)
              Row(
                children: [
                  Expanded(
                    child: AmodoroPressableButton(
                      onTap: () => setState(() => _tab = 0),
                      color: _tab == 0 ? coralBg : cardSurface,
                      lipColor: _tab == 0
                          ? AmodoroTheme.coralPillBorderLight
                          : (isDark
                              ? const Color(0xFF181515)
                              : const Color(0xFFDDD5C8)),
                      lipHeight: 3.5,
                      radius: 999,
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AmodoroTheme.sysIcon(
                            Symbols.casino,
                            size: 18,
                            color: _tab == 0
                                ? coralInk
                                : (isDark
                                    ? Colors.white70
                                    : AmodoroTheme.lightInk),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RULETA AL AZAR',
                            style: AmodoroTheme.googleSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: _tab == 0
                                  ? coralInk
                                  : (isDark
                                      ? Colors.white70
                                      : AmodoroTheme.lightInk),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AmodoroPressableButton(
                      onTap: () => setState(() => _tab = 1),
                      color: _tab == 1 ? coralBg : cardSurface,
                      lipColor: _tab == 1
                          ? AmodoroTheme.coralPillBorderLight
                          : (isDark
                              ? const Color(0xFF181515)
                              : const Color(0xFFDDD5C8)),
                      lipHeight: 3.5,
                      radius: 999,
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AmodoroTheme.sysIcon(
                            Symbols.how_to_vote,
                            size: 18,
                            color: _tab == 1
                                ? coralInk
                                : (isDark
                                    ? Colors.white70
                                    : AmodoroTheme.lightInk),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'VOTAR JUNTOS',
                            style: AmodoroTheme.googleSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: _tab == 1
                                  ? coralInk
                                  : (isDark
                                      ? Colors.white70
                                      : AmodoroTheme.lightInk),
                            ),
                          ),
                        ],
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
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: const Color(0xFFFFDAD6),
                    radius: 16,
                    borderColor: const Color(0xFFE5B5B0),
                    borderWidth: 2.0,
                    subtleShadow: false,
                  ),
                  child: Text(
                    _statusMessage!,
                    style: AmodoroTheme.googleSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3B0D09),
                    ),
                  ),
                ),
              ],

              if (_tab == 0) ...[
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: cardSurface,
                    radius: 26,
                    borderColor: isDark
                        ? const Color(0xFF383232)
                        : const Color(0xFFE2DAD0),
                    borderWidth: 2.0,
                    subtleShadow: false,
                  ),
                  child: Column(
                    children: [
                      AmodoroTheme.sysIcon(
                        Symbols.casino,
                        size: 42,
                        color: coralBg,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Elige inmediatamente 1 actividad al azar de su tablero de PENDIENTES.',
                        textAlign: TextAlign.center,
                        style: AmodoroTheme.googleSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: isDark ? Colors.white : AmodoroTheme.lightInk,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AmodoroPressableButton(
                        onTap: _busy ? null : _spinRoulette,
                        color: coralBg,
                        lipColor: AmodoroTheme.coralPillBorderLight,
                        lipHeight: 3.5,
                        radius: 999,
                        height: 48,
                        child: Center(
                          child: Text(
                            _busy ? 'GIRANDO...' : 'GIRAR RULETA AHORA',
                            style: AmodoroTheme.googleSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: coralInk,
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
                  decoration: AmodoroTheme.cardOutlineBox(
                    color: cardSurface,
                    radius: 26,
                    borderColor: isDark
                        ? const Color(0xFF383232)
                        : const Color(0xFFE2DAD0),
                    borderWidth: 2.0,
                    subtleShadow: false,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Se eligen 4 o 5 pendientes al azar. Cada uno marca Sí o No en secreto. Si coinciden en una sola, gana; si hay empate, pasa automáticamente a otra ronda sin mostrar resultados parciales.',
                        style: AmodoroTheme.googleSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF4E453E),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (voting == null) ...[
                        AmodoroPressableButton(
                          onTap: _busy ? null : _startVoting,
                          color: coralBg,
                          lipColor: AmodoroTheme.coralPillBorderLight,
                          lipHeight: 3.5,
                          radius: 999,
                          height: 48,
                          child: Center(
                            child: Text(
                              'INICIAR VOTACIÓN DE 4–5 AL AZAR',
                              style: AmodoroTheme.googleSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: coralInk,
                              ),
                            ),
                          ),
                        ),
                      ] else if (voting.myVoteSubmitted) ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: AmodoroTheme.cardOutlineBox(
                            color: isDark
                                ? const Color(0xFF2C243B)
                                : const Color(0xFFE8DEF8),
                            radius: 22,
                            borderColor: isDark
                                ? const Color(0xFF4C3C68)
                                : const Color(0xFFC7B6E2),
                            borderWidth: 2.0,
                            subtleShadow: false,
                          ),
                          child: Column(
                            children: [
                              AmodoroTheme.sysIcon(
                                Symbols.lock,
                                size: 32,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F1B18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'RONDA #${voting.roundNumber} · VOTO SECRETO ENVIADO',
                                style: AmodoroTheme.googleSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1F1B18),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Esperando a tu pareja. Los resultados parciales están ocultos.',
                                textAlign: TextAlign.center,
                                style: AmodoroTheme.googleSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF4E453E),
                                ),
                              ),
                              const SizedBox(height: 14),
                              AmodoroPressableButton(
                                onTap: widget.onRefresh,
                                color: isDark
                                    ? AmodoroTheme.darkContainer
                                    : const Color(0xFFFCF9F5),
                                lipColor: isDark
                                    ? const Color(0xFF181515)
                                    : const Color(0xFFDDD5C8),
                                lipHeight: 3.5,
                                radius: 999,
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                child: Center(
                                  child: Text(
                                    'ACTUALIZAR ESTADO',
                                    style: AmodoroTheme.googleSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1F1B18),
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
                          style: AmodoroTheme.googleSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: isDark
                                ? Colors.white70
                                : AmodoroTheme.lightInk,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...voting.candidates.map((c) {
                          final currentVote = _votes[c.id] ?? true;
                          final candColor =
                              AmodoroTheme.parseHexColor(c.bgColor);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: AmodoroTheme.cardOutlineBox(
                              color: candColor,
                              radius: 18,
                              borderColor: AmodoroTheme.darkenForPerspective(
                                candColor,
                                0.16,
                              ),
                              borderWidth: 2.0,
                              subtleShadow: false,
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
                                    style: AmodoroTheme.googleSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F1B18),
                                    ),
                                  ),
                                ),
                                AmodoroPressableButton(
                                  onTap: () {
                                    setState(() {
                                      _votes[c.id] = !currentVote;
                                    });
                                  },
                                  color: currentVote
                                      ? coralBg
                                      : const Color(0xFFFCF9F5),
                                  lipColor: currentVote
                                      ? AmodoroTheme.coralPillBorderLight
                                      : const Color(0xFFDDD5C8),
                                  lipHeight: 3.5,
                                  radius: 999,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    currentVote ? 'SÍ' : 'NO',
                                    style: AmodoroTheme.googleSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: currentVote
                                          ? coralInk
                                          : const Color(0xFF1F1B18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        AmodoroPressableButton(
                          onTap: _busy ? null : () => _submitVotes(voting),
                          color: coralBg,
                          lipColor: AmodoroTheme.coralPillBorderLight,
                          lipHeight: 3.5,
                          radius: 999,
                          height: 48,
                          child: Center(
                            child: Text(
                              _busy ? 'ENVIANDO...' : 'ENVIAR VOTOS',
                              style: AmodoroTheme.googleSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: coralInk,
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
