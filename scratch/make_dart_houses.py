import json
from pathlib import Path

houses = json.loads(Path('scratch/nv_all_houses.json').read_text(encoding='utf-8'))

lines = [
    "// Generated database of all houses and structures in Nizhnevartovsk",
    "abstract final class NizhnevartovskHousesData {",
    "  static const List<String> allHouses = ["
]

for h in houses:
    lines.append(f"    '{h}',")

lines.extend([
    "  ];",
    "",
    "  static List<String> searchHouses(String query, {int limit = 80}) {",
    "    final q = query.trim().toLowerCase();",
    "    if (q.isEmpty) {",
    "      return allHouses.take(limit).toList();",
    "    }",
    "    final words = q.split(RegExp(r'[\\s,]+')).where((w) => w.isNotEmpty).toList();",
    "    if (words.isEmpty) {",
    "      return allHouses.take(limit).toList();",
    "    }",
    "    final results = <String>[];",
    "    for (final house in allHouses) {",
    "      final hLower = house.toLowerCase();",
    "      if (words.every((w) => hLower.contains(w))) {",
    "        results.add(house);",
    "        if (results.length >= limit) break;",
    "      }",
    "    }",
    "    return results;",
    "  }",
    "}",
    ""
])

out_file = Path("services/Frontend/lib/data/nizhnevartovsk_houses.dart")
out_file.parent.mkdir(parents=True, exist_ok=True)
out_file.write_text("\n".join(lines), encoding="utf-8")
print(f"Generated {out_file} with {len(houses)} houses successfully!")
