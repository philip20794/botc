import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

class PdfViewerPage extends StatefulWidget {
  final Uri pdfUrl;
  final String title;

  PdfViewerPage({required this.pdfUrl, required this.title});

  @override
  _PdfViewerPageState createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final controller = PdfViewerController();
  PdfTextSearcher? _textSearcher;

  bool get _isViewerReady => _textSearcher != null;

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _textSearcher?.removeListener(_update);
    _textSearcher?.dispose();
    super.dispose();
  }

  void _searchText(String searchText) {
    _textSearcher?.startTextSearch(searchText, caseInsensitive: true);
  }

  void _goToPreviousResult() {
    if (_textSearcher?.hasMatches ?? false) {
      _textSearcher!.goToPrevMatch();
    }
  }

  void _goToNextResult() {
    if (_textSearcher?.hasMatches ?? false) {
      _textSearcher!.goToNextMatch();
    }
  }

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    if (!mounted || _textSearcher != null) return;
    final searcher = PdfTextSearcher(controller)..addListener(_update);
    setState(() => _textSearcher = searcher);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF4a3b5e),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: !_isViewerReady
                ? null
                : () async {
                    String? searchText = await showSearch(
                      context: context,
                      delegate: PdfSearchDelegate(),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    if (searchText != null && searchText.isNotEmpty) {
                      _searchText(searchText);
                    }
                  },
          ),
        ],
      ),
      body: PdfViewer.uri(
        widget.pdfUrl,
        controller: controller,
        params: PdfViewerParams(
          backgroundColor: const Color(0xFF21182d),
          onViewerReady: _onViewerReady,
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
            return Center(
              child: CircularProgressIndicator(
                value: totalBytes != null ? bytesDownloaded / totalBytes : null,
                backgroundColor: Colors.white24,
              ),
            );
          },
          errorBannerBuilder: (context, error, stackTrace, documentRef) =>
              _PdfLoadError(title: widget.title),
          pagePaintCallbacks: _textSearcher == null
              ? const []
              : [_textSearcher!.pageTextMatchPaintCallback],
        ),
      ),
      floatingActionButton: (_textSearcher?.hasMatches ?? false)
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _goToPreviousResult,
                  child: Icon(Icons.arrow_back),
                  heroTag: 'previous',
                  tooltip: 'Vorheriges Ergebnis',
                ),
                SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _goToNextResult,
                  child: Icon(Icons.arrow_forward),
                  heroTag: 'next',
                  tooltip: 'Nächstes Ergebnis',
                ),
              ],
            )
          : const SizedBox(),
    );
  }
}

class _PdfLoadError extends StatelessWidget {
  const _PdfLoadError({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined,
                color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              strings.pdfLoadError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class PdfSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'Search PDF';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = ''; // Clear the current query
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(
            context, ''); // Close the search dialog and return an empty string
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Trigger the search when the user submits their query
    Future.delayed(Duration.zero, () {
      close(context, query); // Close the search dialog and return the query
    });

    return Center(
      child: Text("Suchtext: $query"), // Beispiel zur Anzeige des Suchtextes
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Vorschläge basierend auf dem aktuellen Query implementieren
    final suggestions =
        query.isEmpty ? [] : []; // Hier echte Vorschläge hinzufügen

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(suggestions[index]),
          onTap: () {
            query = suggestions[index]; // Bei Auswahl den Vorschlag übernehmen
            showResults(context); // Zeige die Ergebnisse an
          },
        );
      },
    );
  }
}
