import 'package:flutter/material.dart';

/// Informational screen explaining travel insurance — what each coverage
/// category means, what to watch out for and where to get help in an emergency.
class TravelInsuranceInfoScreen extends StatelessWidget {
  const TravelInsuranceInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cestovní pojištění — co kryjí?'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- INTRO ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✈️ Co by mělo dobré cestovní pojištění krýt?',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Pojištění se výrazně liší cenou i rozsahem krytí. '
                  'Tato stránka ti pomůže pochopit, co jednotlivé složky znamenají '
                  'a co si hlídat před výběrem pojišťovny.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ---- COVERAGE CARDS ----
          _CoverageCard(
            icon: '🏥',
            color: Colors.red.shade100,
            title: 'Léčebné výlohy v zahraničí',
            priority: 'Nejdůležitější složka',
            priorityColor: Colors.red,
            body:
                'Hradí náklady na ošetření, hospitalizaci, operace a repatriaci zpět do ČR. '
                'Bez tohoto krytí může hospitalizace v USA stát přes 1 milion Kč.',
            tips: const [
              'Minimum: 3 000 000 Kč (120 000 EUR)',
              'Pro USA/Kanadu doporučeno 10 000 000+ Kč',
              'Zkontroluj, zda kryje ambulantní i úrazové ošetření',
              'Asistenční linka 24/7 musí být v češtině',
            ],
          ),

          _CoverageCard(
            icon: '🧳',
            color: Colors.brown.shade100,
            title: 'Zavazadla a osobní věci',
            priority: 'Důležité',
            priorityColor: Colors.orange,
            body:
                'Krytí ztráty, poškození nebo odcizení zavazadel. '
                'Pozor — mnohé pojistky mají významné výluky.',
            tips: const [
              'Elektronika (laptop, fotoaparát) bývá omezena nebo vyloučena',
              'Výška náhrady za jeden předmět je typicky 3 000–10 000 Kč',
              'Hotovost a cennosti mají vlastní, nižší limit',
              'Poškozená zavazadla — nutno sepsat protokol na letišti',
            ],
          ),

          _CoverageCard(
            icon: '✈️',
            color: Colors.blue.shade100,
            title: 'Zpoždění letu a zmeškaný spoj',
            priority: 'Praktické',
            priorityColor: Colors.blue,
            body:
                'Náhrada nákladů při zpoždění letu (jídlo, nocleh) nebo při zmeškaném '
                'přípojném spoji.',
            tips: const [
              'Krytí se aktivuje typicky po 4–6 hodinách zpoždění',
              'Zmeškaný spoj: hradí nový lístek nebo nocleh',
              'Zrušení letu ze strany dopravce — storno kryje pojišťovna, ne dopravce',
              'Nutné mít doklad od letecké společnosti o zpoždění',
            ],
          ),

          _CoverageCard(
            icon: '⚖️',
            color: Colors.purple.shade100,
            title: 'Odpovědnost za škodu třetím osobám',
            priority: 'Důležité v EU',
            priorityColor: Colors.orange,
            body:
                'Krytí škod, které způsobíš jiné osobě nebo jejímu majetku. '
                'Relevantní zejména při sportech, v hotelu nebo při dovolené s dětmi.',
            tips: const [
              'Typické krytí: 3 000 000 – 10 000 000 Kč',
              'Pozor: škody v pronajatém autě krytí NEzahrnuje (to řeší autopojistka)',
              'Ve Francii a Německu bývají vymáhány i drobné škody (poškozená dekorace v hotelu)',
            ],
          ),

          _CoverageCard(
            icon: '❌',
            color: Colors.red.shade50,
            title: 'Storno cesty',
            priority: 'Volitelné',
            priorityColor: Colors.grey,
            body:
                'Vrácení předem zaplacených nákladů za cestu, pokud ji musíš zrušit '
                'z důvodu nemoci, úrazu nebo jiné události.',
            tips: const [
              'Musí být uzavřeno PŘED stornem — zpětně nelze',
              'Uznané důvody: nemoc, smrt v rodině, úraz, živelní pohroma',
              'Neuznané důvody: „nechce se mi jet", pracovní povinnosti',
              'Krytí bývá 80–100 % zaplacených nákladů',
            ],
          ),

          _CoverageCard(
            icon: '🎿',
            color: Colors.teal.shade100,
            title: 'Sportovní aktivity',
            priority: 'Povinné při sportu',
            priorityColor: Colors.red,
            body:
                'Standardní pojistky NEVZTAHUJÍ na rizikové sporty. '
                'Při lyžování, snowboardingu, potápění nebo cyklistice nutno dokoupit příplatek.',
            tips: const [
              'Lyžování / snowboard: nutný sportovní příplatek',
              'Potápění: příplatek, někdy jen do určité hloubky',
              'Rafting, paragliding, paragliding: specifické podmínky',
              'Závodní sport je obvykle vyloučen úplně',
            ],
          ),

          _CoverageCard(
            icon: '🚑',
            color: Colors.green.shade100,
            title: 'Asistenční služby 24/7',
            priority: 'Musí mít',
            priorityColor: Colors.red,
            body:
                'Telefonická podpora při náhlé nehodě nebo zdravotním problému v zahraničí. '
                'Organizace záchranné akce, tlumočení, právní podpora.',
            tips: const [
              'Číslo asistenční linky ulož do telefonu PŘED cestou',
              'Linka musí fungovat v češtině nebo slovenštině',
              'Organizuje přesun do nemocnice a repatriaci',
              'Při hospitalizaci kontaktuj asistenci — jinak nemusí uhradit',
            ],
          ),

          const SizedBox(height: 24),

          // ---- PRICE COMPARISON ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡 Orientační ceny pro Evropu', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                const _PriceRow('Základní (léčebné výlohy)', '200–600 Kč / rok'),
                const _PriceRow('Komplexní (+ zavazadla, odpovědnost)', '600–1 500 Kč / rok'),
                const _PriceRow('Lyžařský příplatek', '+200–500 Kč'),
                const _PriceRow('USA / Kanada / exotika', '1 500–5 000 Kč / rok'),
                const SizedBox(height: 8),
                Text(
                  'Tip: Roční smlouva je výrazně levnější než jednorázové pojištění '
                  'při každé cestě. Při více než 2 cestách ročně se roční smlouva vyplatí.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ---- MOST COMMON MISTAKES ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠️ Nejčastější chyby při pojištění',
                    style: theme.textTheme.titleSmall?.copyWith(color: Colors.orange.shade800)),
                const SizedBox(height: 8),
                ...[
                  'Příliš nízký limit léčebných výloh (pod 3 mil. Kč)',
                  'Sjednání AŽ po příjezdu do destinace — pozdě!',
                  'Zapomenutí na sportovní příplatek na lyžích',
                  'Neuložení čísla asistenční linky před odletem',
                  'Nezavolání asistenci PŘED platbou za nemocnici',
                  'Pojistka vypršela a uživatel si nevšiml',
                ].map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(e, style: theme.textTheme.bodySmall)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------

class _CoverageCard extends StatelessWidget {
  final String icon;
  final Color color;
  final String title;
  final String priority;
  final Color priorityColor;
  final String body;
  final List<String> tips;

  const _CoverageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.priority,
    required this.priorityColor,
    required this.body,
    required this.tips,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 180 / 255),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Text(icon, style: const TextStyle(fontSize: 28)),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(priority,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: priorityColor, fontWeight: FontWeight.bold)),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(body, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('→ ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: priorityColor)),
                    Expanded(
                        child: Text(t, style: theme.textTheme.bodySmall)),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String price;
  const _PriceRow(this.label, this.price);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall)),
          Text(price,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
