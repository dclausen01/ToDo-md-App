import 'package:flutter_test/flutter_test.dart';
import 'package:todo_md_app/src/ui/card_inline.dart';

void main() {
  group('card inline helpers', () {
    test('stripInlineMarkdown removes bold and wikilink brackets', () {
      expect(stripInlineMarkdown('**Hello** [[Some Note]]'),
          'Hello Some Note');
    });

    test('extractLinks finds wikilinks, embeds and urls', () {
      final links = extractLinks(
          '- [ ] Task [[Note A]] ![[Attachment.pdf]] https://example.org/x');
      expect(links.map((l) => l.kind), containsAll([
        CardLinkKind.wiki,
        CardLinkKind.embed,
        CardLinkKind.url,
      ]));
      final wiki = links.firstWhere((l) => l.kind == CardLinkKind.wiki);
      expect(wiki.target, 'Note A');
    });

    test('wikilink display drops folder, extension and alias', () {
      final links = extractLinks('[[Folder/My Note_abc123|Alias]]');
      expect(links.single.display, 'Alias');
    });
  });
}
