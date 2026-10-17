import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/services/firestore_game_repository.dart';
import 'package:blood_on_the_clocktower/services/game_record_upload_queue.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Diagnostics are visible only after opening Settings → Statistics sync.
/// Background publication deliberately never opens a notification or overlay.
class StatisticsSyncScreen extends StatelessWidget {
  const StatisticsSyncScreen({super.key});

  String _text(BuildContext context, String de, String en) =>
      Localizations.localeOf(context).languageCode == 'de' ? de : en;

  String _date(BuildContext context, DateTime? date) {
    if (date == null) return _text(context, 'Noch nie', 'Never');
    return DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal());
  }

  String _outcome(BuildContext context, GameRecordUploadIssue? issue) {
    if (issue == null) {
      return _text(context, 'Wartet auf Upload', 'Waiting for upload');
    }
    return switch (issue.outcome) {
      'invalid' => _text(context, 'Ungültiger Datensatz', 'Invalid record'),
      'tooLarge' => _text(context, 'Datensatz zu groß', 'Record too large'),
      'retryLater' when issue.errorCode == 'permission-denied' =>
        _text(context, 'Firestore-Zugriff verweigert', 'Firestore permission denied'),
      'retryLater' when issue.errorCode == 'unavailable' =>
        _text(context, 'Firebase nicht erreichbar', 'Firebase unavailable'),
      'retryLater' => _text(
          context, 'Upload fehlgeschlagen – erneuter Versuch möglich',
          'Upload failed – retry available'),
      _ => _text(context, 'Wartet auf Upload', 'Waiting for upload'),
    };
  }

  Widget _metric(BuildContext context, String label, int value,
      IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: GrimoireColors.antiqueGold, size: 22),
          const SizedBox(height: 6),
          Text('$value',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: GrimoireColors.ivory,
                  )),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(color: GrimoireColors.secondaryText,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String title, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GrimoireSectionHeading(title: title, icon: icon),
      );

  Widget _pendingRow(
      BuildContext context, GameRecord record, GameRecordUploadIssue? issue) {
    return Padding(
      key: ValueKey('pending-game-${record.gameId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: GrimoirePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(record.script.name,
              style: const TextStyle(fontWeight: FontWeight.bold,
                  color: GrimoireColors.ivory)),
          const SizedBox(height: 4),
          Text('${_date(context, record.endedAt)} · ${record.playerCount} ' +
              _text(context, 'Spieler', 'players'),
              style: const TextStyle(color: GrimoireColors.secondaryText)),
          const SizedBox(height: 8),
          Text(_outcome(context, issue),
              style: TextStyle(color: issue == null
                  ? GrimoireColors.secondaryText : GrimoireColors.antiqueGold)),
          if (issue != null)
            Text(_text(context, 'Letzter Versuch: ', 'Last attempt: ') +
                _date(context, issue.attemptedAt),
                style: const TextStyle(
                    color: GrimoireColors.secondaryText, fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<GameRecordUploadQueue>();
    final uploader = context.read<FirestoreGameRepository>();
    final pending = queue.records;
    final confirmed = queue.confirmedUploads;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_text(context, 'Statistik-Synchronisierung',
              'Statistics synchronization')),
          backgroundColor: Colors.transparent,
        ),
        body: ListView(
          key: const ValueKey('statistics-sync-content'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            GrimoirePanel(
              emphasized: true,
              child: Row(children: [
                _metric(context, _text(context, 'Übertragen', 'Uploaded'),
                    queue.confirmedUploadCount, Icons.cloud_done_outlined),
                const SizedBox(width: 8),
                _metric(context, _text(context, 'Ausstehend', 'Pending'),
                    queue.pendingCount, Icons.schedule_outlined),
                const SizedBox(width: 8),
                _metric(context, _text(context, 'Probleme', 'Issues'),
                    queue.failedCount, Icons.info_outline),
              ]),
            ),
            const SizedBox(height: 16),
            GrimoirePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_text(context, 'Letzter Upload-Versuch',
                          'Last upload attempt'),
                      style: const TextStyle(
                          color: GrimoireColors.secondaryText)),
                  Text(_date(context, queue.lastAttemptAt),
                      key: const ValueKey('last-upload-attempt')),
                  const SizedBox(height: 8),
                  Text(_text(context, 'Letzte Firestore-Bestätigung',
                          'Last Firestore confirmation'),
                      style: const TextStyle(
                          color: GrimoireColors.secondaryText)),
                  Text(_date(context, queue.lastSuccessAt)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('retry-statistics-upload'),
                      onPressed: queue.isUploading || pending.isEmpty
                          ? null
                          : () async {
                              await uploader.publishPending(queue);
                            },
                      icon: queue.isUploading
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync),
                      label: Text(queue.isUploading
                          ? _text(context, 'Synchronisiere …', 'Syncing …')
                          : _text(context, 'Jetzt synchronisieren',
                              'Sync now')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _heading(context,
                _text(context, 'Warteschlange (${pending.length})',
                    'Pending games (${pending.length})'),
                Icons.schedule_outlined),
            if (pending.isEmpty)
              GrimoirePanel(
                child: Text(_text(context,
                    'Keine Spiele warten auf einen Upload.',
                    'No games are waiting for upload.')),
              )
            else
              for (final record in pending)
                _pendingRow(context, record, queue.issueFor(record.gameId)),
            const SizedBox(height: 20),
            _heading(context,
                _text(context, 'Erfolgreich bestätigt (${confirmed.length})',
                    'Confirmed uploads (${confirmed.length})'),
                Icons.cloud_done_outlined),
            if (confirmed.isEmpty)
              GrimoirePanel(
                child: Text(_text(context,
                    'Noch keine Upload-Bestätigung auf diesem Gerät erfasst.',
                    'No confirmed upload has been recorded on this device.')),
              )
            else
              for (final receipt in confirmed.take(30))
                Padding(
                  key: ValueKey('confirmed-game-${receipt.gameId}'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GrimoirePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(receipt.scriptName,
                            style: const TextStyle(
                                color: GrimoireColors.ivory,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_text(context, 'Hochgeladen: ', 'Uploaded: ') +
                            _date(context, receipt.confirmedAt),
                            style: const TextStyle(
                                color: GrimoireColors.secondaryText)),
                        if (receipt.alreadyExisted)
                          Text(_text(context,
                              'Bereits in Firestore vorhanden',
                              'Already present in Firestore'),
                              style: const TextStyle(
                                  color: GrimoireColors.secondaryText)),
                      ],
                    ),
                  ),
                ),
            if (confirmed.length > 30)
              Text(_text(context, 'Es werden die letzten 30 angezeigt.',
                      'Showing the most recent 30.'),
                  style: const TextStyle(
                      color: GrimoireColors.secondaryText)),
            const SizedBox(height: 20),
            Text(
              _text(context,
                  'Die Zahlen gelten nur für bestätigte Uploads, die diese '
                  'App-Installation seit Einführung dieser Übersicht erfasst '
                  'hat. Bereits früher hochgeladene Spiele sind nicht '
                  'rückwirkend zählbar. Spielernamen werden nicht hochgeladen.',
                  'Counts cover only confirmed uploads tracked by this '
                  'app installation since the status view was introduced. '
                  'Earlier uploads cannot be counted retroactively. '
                  'Player names are not uploaded.'),
              style: const TextStyle(
                  color: GrimoireColors.secondaryText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
