#!/usr/bin/env python3
"""Endpoints the backend serves that nothing in the app calls.

PLAN-5 III.D.2 asks for this by name: "Add a meta-test that fails when an
endpoint has no caller in the app — §6.7's audit was manual and the drift will
recur." Drift in this direction is not a tidiness problem. Three of §7's
features were *built and verified* on the server and reachable from no screen
(PLAN-5 §I.3: T7.1 / T7.5 / T7.6 → Phase 9), which is work paid for and not
delivered, and nothing reported it because a server has no way to know that
nobody is calling.

WHY THIS IS A SCRIPT AND NOT A TEST. It needs both repositories at once, and
neither one's test suite can see the other. Run it from the folder that holds
them as siblings, which is how README.md says to lay them out:

    python3 scripts/check-endpoint-callers.py
    python3 scripts/check-endpoint-callers.py --fail-on-orphans   # for CI

WHAT IT CANNOT SEE, stated plainly so the output is not over-trusted. A path
built at runtime from pieces the app never spells out is invisible to it, and so
is an endpoint called only by something that is not this app — ops tooling, a
webhook, a future admin console. Both directions are why this prints a list to
read rather than failing by default. Treat a name here as a question, not a
verdict.
"""

import argparse
import os
import re
import sys

MAPPING = re.compile(
    r'@(Get|Post|Put|Delete|Patch|Request)Mapping\s*\(\s*(?:value\s*=\s*)?"([^"]*)"')
CLASS_MAPPING = re.compile(r'@RequestMapping\s*\(\s*"([^"]+)"')

# A path variable is written {id} on the server and interpolated on the client,
# so the two never match literally. Compare the fixed prefix instead.
PATH_VAR = re.compile(r'\{[^}]+\}')

# Surfaces the app is not the client for, so "no caller in the app" is the
# expected answer and not a finding. Listing them separately is the difference
# between a report somebody reads and a report somebody learns to ignore:
#
#   * /admin-user/ and /super-user/ are the ops desk and one-off setup. Some of
#     the ops surface IS reached from the app (ops_queue_screen), which is why
#     this is a prefix rule and not a whole-controller one.
#   * /common/health exists for a load balancer. A caller in the app would be
#     the surprise.
OPS_PREFIXES = (
    '/api/v1/yapan/admin-user/',
    '/api/v1/yapan/super-user/',
    '/api/v1/yapan/common/health',
)


def endpoints(backend):
    """(path, method_name, file) for every mapping in every controller."""
    found = []
    controllers = os.path.join(backend, 'src/main/java/com/actually/yapan/controller')
    if not os.path.isdir(controllers):
        sys.exit("no controllers at %s — run this from the folder holding the repos as siblings"
                 % controllers)

    for name in sorted(os.listdir(controllers)):
        if not name.endswith('.java'):
            continue
        source = open(os.path.join(controllers, name), encoding='utf-8').read()

        # The class-level @RequestMapping is the prefix every method hangs off.
        head = source.split('class ', 1)[0]
        prefix_match = CLASS_MAPPING.search(head)
        prefix = prefix_match.group(1) if prefix_match else ''

        for verb, path in MAPPING.findall(source):
            if verb == 'Request' and path == prefix:
                continue  # the class annotation itself
            found.append((prefix + path, name))
    return found


def app_text(app):
    """Every line of Dart, concatenated. Crude and correct: a path is a string,
    and a string that appears nowhere in the app is not being sent."""
    chunks = []
    lib = os.path.join(app, 'lib')
    if not os.path.isdir(lib):
        sys.exit("no lib/ at %s" % lib)
    for root, _, files in os.walk(lib):
        for f in files:
            if f.endswith('.dart'):
                chunks.append(open(os.path.join(root, f), encoding='utf-8').read())
    return '\n'.join(chunks)


def called(path, haystack):
    literal = PATH_VAR.split(path)[0].rstrip('/')
    if not literal:
        return True  # nothing fixed to search for; do not accuse it
    return literal in haystack


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--backend', default='JeevikaService')
    ap.add_argument('--app', default='Yapan')
    ap.add_argument('--fail-on-orphans', action='store_true',
                    help='exit 1 if any endpoint has no caller (for CI)')
    args = ap.parse_args()

    found = endpoints(args.backend)
    haystack = app_text(args.app)

    uncalled = [(p, f) for p, f in found if not called(p, haystack)]
    ops = [(p, f) for p, f in uncalled if p.startswith(OPS_PREFIXES)]
    orphans = [(p, f) for p, f in uncalled if not p.startswith(OPS_PREFIXES)]

    print("%d endpoints. %d have no caller in the app: %d are ops surfaces, "
          "%d are not.\n" % (len(found), len(uncalled), len(ops), len(orphans)))

    if orphans:
        print("NO CALLER, AND THE APP IS THE CLIENT — read these:")
        width = max(len(p) for p, _ in orphans)
        for path, f in sorted(orphans):
            print("  %-*s  %s" % (width, path, f))
        print("\nEach is either work that is built and unreachable from any screen —"
              "\nwhich is what happened to T7.1, T7.5 and T7.6 — or a path the app"
              "\nassembles at runtime and this cannot see. Both are worth knowing."
              "\nNeither is automatically a defect.\n")
    else:
        print("Every endpoint the app is the client for is named somewhere in it.\n")

    if ops:
        print("NO CALLER, AND NONE EXPECTED (ops desk, setup, load balancer):")
        for path, f in sorted(ops):
            print("  %s" % path)

    if orphans and args.fail_on_orphans:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
