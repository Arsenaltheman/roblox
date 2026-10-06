"""Records game pass / developer product ids for src/shared/Config/Products.luau.

Passes and products are created by the owner in Creator Hub (Monetization -> Passes / Developer
Products) with the names and prices printed by --list. Then their ids are recorded here:

  python3 tools/cloud/create_products.py --list
  python3 tools/cloud/create_products.py --set VIP=123456 DoubleCash=234567 ...

This writes assets/ids/products.json and regenerates src/shared/Config/AssetIds.luau. (Creating them
through Open Cloud is possible on newer API versions, but prices and icons are worth a human look, and
the owner has to answer the paid-random-items questions for luck products anyway.)
"""

import argparse
import re

from common import ROOT, load_ids, save_ids


def catalog() -> list[dict]:
    text = (ROOT / "src" / "shared" / "Config" / "Products.luau").read_text()
    pattern = re.compile(r'\{ key = "(\w+)", kind = "(\w+)", price = (\d+), name = "([^"]+)", description = "([^"]+)"')
    return [
        {"key": m[0], "kind": m[1], "price": int(m[2]), "name": m[3], "description": m[4]}
        for m in pattern.findall(text)
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--set", nargs="+", metavar="KEY=ID")
    args = parser.parse_args()
    ids = load_ids("products")
    items = catalog()
    if args.list or not args.set:
        for item in items:
            have = ids.get(item["key"], {}).get("id", "-")
            print(f"{item['kind']:13s} {item['key']:17s} R${item['price']:<5d} id={have:<12} {item['name']}: {item['description']}")
    if args.set:
        known = {item["key"] for item in items}
        for pair in args.set:
            key, _, value = pair.partition("=")
            if key not in known or not value.isdigit():
                raise SystemExit(f"bad entry {pair!r}: key must be one of the catalog keys and id a number")
            ids[key] = {"id": value}
        save_ids("products", ids)
        print(f"saved {len(args.set)} id(s)")


if __name__ == "__main__":
    main()
