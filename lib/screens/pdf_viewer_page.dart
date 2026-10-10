import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfViewerPage extends StatefulWidget {
  final Uri pdfUrl;
  final String title;

  PdfViewerPage({required this.pdfUrl, required this.title});

  @override
  _PdfViewerPageState createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final controller = PdfViewerController();
  late final PdfTextSearcher textSearcher;

  @override
  void initState() {
    super.initState();
    textSearcher = PdfTextSearcher(controller)..addListener(_update);
  }

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    textSearcher.removeListener(_update);
    textSearcher.dispose();
    super.dispose();
  }

  void _searchText(String searchText) {
    textSearcher.startTextSearch(searchText, caseInsensitive: true);
  }

  void _goToPreviousResult() {
    if (textSearcher.hasMatches) {
      textSearcher.goToPrevMatch();
    }
  }

  void _goToNextResult() {
    if (textSearcher.hasMatches) {
      textSearcher.goToNextMatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Color(0xFFFAFAFA),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
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
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
            return Center(
              child: CircularProgressIndicator(
                value: totalBytes != null ? bytesDownloaded / totalBytes : null,
                backgroundColor: Colors.grey,
              ),
            );
          },
          pagePaintCallbacks: [
            textSearcher.pageTextMatchPaintCallback,
          ],
        ),
      ),
      floatingActionButton: textSearcher.hasMatches
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
          : SizedBox(),
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
