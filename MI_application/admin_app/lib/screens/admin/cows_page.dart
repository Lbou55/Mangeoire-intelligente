import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../widgets/appetite.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';
import '../../widgets/ico.dart';
import 'cow_detail_page.dart';
import 'cow_form_page.dart';

typedef _CowsData = ({List<Cow> cows, Map<String, Appetite?> appetite});

class CowsPage extends StatefulWidget {
  const CowsPage({super.key});

  @override
  State<CowsPage> createState() => _CowsPageState();
}

class _CowsPageState extends State<CowsPage> {
  final _key = GlobalKey<AsyncBodyState<_CowsData>>();
  final _search = TextEditingController();
  String _query = '';
  Appetite? _filter;
  bool _filterOn = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_CowsData> _load() async {
    final cows = await FarmApi.instance.cows();
    Map<String, Appetite?> appetite = {};
    try {
      appetite = await FarmApi.instance.appetiteByCow();
    } catch (_) {}
    return (cows: cows, appetite: appetite);
  }

  Future<void> _add() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CowFormPage()),
    );
    if (created == true) _key.currentState?.reload();
  }

  Future<void> _open(Cow cow) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CowDetailPage(cow: cow)),
    );
    if (changed == true) _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: Ico('add', taille: 22, couleur: p.surPrimaire),
        label: Text(context.t('add_cow'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AsyncBody<_CowsData>(
        key: _key,
        load: _load,
        builder: (context, d) {
          final shown = d.cows.where((c) {
            if (_query.isNotEmpty &&
                !c.cowId.toLowerCase().contains(_query) &&
                !c.breed.toLowerCase().contains(_query)) {
              return false;
            }
            if (_filterOn && d.appetite[c.cowId] != _filter) return false;
            return true;
          }).toList();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: decorationChamp(
                  p,
                  indice: context.t('search_cow'),
                  debut: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ChoiceChip(
                    label: Text(context.t('filter_all')),
                    selected: !_filterOn,
                    onSelected: (_) => setState(() => _filterOn = false),
                  ),
                  for (final a in Appetite.values) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(appetiteLabel(context, a)),
                      selected: _filterOn && _filter == a,
                      onSelected: (_) => setState(() {
                        _filterOn = true;
                        _filter = a;
                      }),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              if (d.cows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Column(children: [
                    const AvatarIco(icon: 'nav_animals', size: 88),
                    const SizedBox(height: 14),
                    Text(context.t('no_cows'),
                        textAlign: TextAlign.center, style: TextStyle(color: p.texte2)),
                  ]),
                )
              else if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(context.t('no_result'), style: TextStyle(color: p.texte2)),
                  ),
                ),
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CarteDouce(
                    onTap: () => _open(shown[i]),
                    child: Row(children: [
                      Hero(
                        tag: 'cow_${shown[i].cowId}',
                        child: AvatarIco(
                          icon: 'nav_animals',
                          warning: d.appetite[shown[i].cowId] == Appetite.decreasing,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(shown[i].cowId,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            '${shown[i].breed} · ${shown[i].weightKg.toStringAsFixed(0)} kg · ${ageText(context, shown[i].ageMonths)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.texte2, fontSize: 13),
                          ),
                        ]),
                      ),
                      AppetitePill(d.appetite[shown[i].cowId]),
                    ]),
                  ).stagger(i),
                ),
            ],
          );
        },
      ),
    );
  }
}
