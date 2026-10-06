"""Records game pass / developer product ids for src/shared/Config/Products.luau.

Passes and products are created by the owner in Creator Hub (Monetization -> Passes / Developer
Products) with the names and prices printed by --list. Then their ids are recorded here:

  python3 tools/cloud/create_products.py --list
  python3 tools/cloud/create_products.py --set VIP=123456 DoubleCash=234567 ...
  python3 tools/cloud/create_products.py --subscription EXP-1234...   (Sheriff's Club)
  python3 tools/cloud/create_products.py --group 12345678             (group reward)

This writes assets/ids/products.json and regenerates src/shared/Config/AssetIds.luau. (Creating them
through Open Cloud is possible on newer API versions, but prices and icons are worth a human look, and
the owner has to answer the paid-random-items questions for luck products anyway.)
"""

import argparse
import re

from common import ROOT, load_ids, save_ids


def catalog() -> list[dict]:
    """Every product block in Products.luau, whatever order its fields are in."""
    text = (ROOT / "src" / "shared" / "Config" / "Products.luau").read_text()
    items = []
    for block in re.findall(r"\{\s*\n((?:\s*\w+ = [^\n]+\n)+?)\s*\}", text):
        fields = dict(re.findall(r'(\w+) = (?:"([^"]*)"|(\d+))[^\n]*', block) and
                      [(m[0], m[1] if m[1] != "" else m[2]) for m in re.findall(r'(\w+) = (?:"([^"]*)"|(\d+))', block)])
        if "key" in fields and "kind" in fields and "price" in fields:
            items.append({
                "key": fields["key"],
                "kind": fields["kind"],
                "price": int(fields["price"]),
                "name": fields.get("name", ""),
                "description": fields.get("description", ""),
            })
    return items


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--set", nargs="+", metavar="KEY=ID")
    parser.add_argument("--subscription", metavar="SUBSCRIPTION_ID", help="Sheriff's Club subscription id (a string)")
    parser.add_argument("--group", metavar="GROUP_ID", help="Roblox group id for the group reward (0 = off)")
    args = parser.parse_args()
    ids = load_ids("products")
    items = catalog()
    if args.subscription:
        ids["__subscription"] = {"id": args.subscription}
        save_ids("products", ids)
        print("saved subscription id")
    if args.group:
        if not args.group.isdigit():
            raise SystemExit("group id must be a number")
        ids["__group"] = {"id": args.group}
        save_ids("products", ids)
        print("saved group id")
    if args.list or not (args.set or args.subscription or args.group):
        for item in items:
            have = ids.get(item["key"], {}).get("id", "-")
            if item["kind"] == "subscription":
                have = ids.get("__subscription", {}).get("id", "-")
            print(f"{item['kind']:13s} {item['key']:17s} R${item['price']:<5d} id={have:<12} {item['name']}: {item['description']}")
    if args.set:
        known = {item["key"] for item in items}
        for pair in args.set:
            key, _, value = pair.partition("=")
            if key not in known or not value.isdigit() or key == "SheriffClub":
                raise SystemExit(f"bad entry {pair!r}: key must be one of the catalog keys and id a number")
            ids[key] = {"id": value}
        save_ids("products", ids)
        print(f"saved {len(args.set)} id(s)")


if __name__ == "__main__":
    main()
