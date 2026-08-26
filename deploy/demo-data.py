#!/usr/bin/env python3
"""Seed the server with demo data, so the app has something to show.

    python deploy/demo-data.py            # seed
    python deploy/demo-data.py --teardown # remove what it created

Every screen on a fresh server is empty, which makes the app impossible to
judge — you cannot tell a layout problem from a missing row.

⚠️ **This writes to the live database.** Everything it creates is deliberately
recognisable: accounts on the 9000009xxx range, obviously fictional names, and
job titles prefixed `[demo]`. Tear it down before real users exist.

## Why the API and not SQL

Posting through the real endpoints means the rows are valid by construction —
schedules expand, addresses geocode into the right columns, reputations
initialise. A hand-written INSERT would have to reproduce every rule in
`OrganiserServiceImpl` and would silently get some of them wrong, which is worse
than no demo data because it looks real.

⚠️ It depends on the OTP being `000000` for every number, which is true today
and is tracked as O-18. **When SMS is wired this script stops working**, and
that is the correct outcome — a seeding tool that can create accounts on a
production system is not something to keep working.
"""

import argparse
import json
import random
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta

BASE = "https://yapan.duckdns.org/api/v1/yapan"

# Bijnor, Uttar Pradesh — where the product owner is testing. Jobs are scattered
# within a few kilometres so the Earning Zone's distance filter has something to
# actually filter.
CENTRE_LAT = 29.3720
CENTRE_LNG = 78.1350

# 9000009xxx: outside any real allocation, and greppable.
PHONE_PREFIX = "900000"

DEMO_TAG = "[demo]"


class Api:
    """Enough HTTP for this script. No dependencies."""

    def __init__(self):
        self.auth = None
        self.atsh = None

    def call(self, method, path, body=None, public=False):
        url = BASE + path
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", "application/json")
        if not public:
            if not self.auth:
                raise RuntimeError("not signed in")
            req.add_header("Authorization", self.auth)
            req.add_header("atsh", self.atsh)
        try:
            with urllib.request.urlopen(req, timeout=30) as res:
                return res.status, json.loads(res.read().decode() or "{}"), dict(res.headers)
        except urllib.error.HTTPError as e:
            raw = e.read().decode()
            try:
                return e.code, json.loads(raw or "{}"), dict(e.headers)
            except ValueError:
                return e.code, {"message": raw[:200]}, dict(e.headers)

    def sign_in(self, phone, full_name, email):
        """Sign up if new, sign in if not. Returns True when authenticated."""
        self.call("POST", "/common/otp-request", {"phone": phone}, public=True)

        status, body, headers = self.call(
            "POST", "/common/login-verify", {"phone": phone, "otp": "000000"}, public=True)
        if status != 200 or not headers.get("authorization"):
            status, body, headers = self.call(
                "POST", "/common/sign-up-verify",
                {"fullName": full_name, "phone": phone, "email": email, "otp": "000000"},
                public=True)
        if status != 200 or not headers.get("authorization"):
            print("   ! could not sign in %s: %s" % (phone, body.get("message")))
            return False
        self.auth = headers["authorization"]
        self.atsh = headers.get("atsh")
        return True


# ── The cast ─────────────────────────────────────────────────────────────
#
# Names are plainly fictional and the roles are the ones this product is
# actually about: households who need help and people who do the work.
PEOPLE = [
    ("Asha Demo", "gasta.demo.asha@gmail.com"),
    ("Ramesh Demo", "gasta.demo.ramesh@gmail.com"),
    ("Sunita Demo", "gasta.demo.sunita@gmail.com"),
    ("Imran Demo", "gasta.demo.imran@gmail.com"),
    ("Kavita Demo", "gasta.demo.kavita@gmail.com"),
]

# Titles read like something a person would actually post, because a screen full
# of "Test job 1" tells you nothing about whether the screen works.
JOBS = [
    ("Morning cleaning and dishes", "Two rooms and a kitchen. Please ring the bell twice."),
    ("Cook for evening meal", "Simple vegetarian food for four people."),
    ("Field levelling before sowing", "About one bigha. Bring your own tools."),
    ("Fix the ceiling fan", "It runs slow and makes a noise."),
    ("Help unloading cement bags", "Twenty bags from the road to the back."),
    ("Wash and iron for the week", "Mostly shirts and one saree."),
    ("Paint the front room", "Walls only, we have the paint."),
    ("Look after grandmother in the afternoon", "She needs company and her medicines on time."),
]


def scatter(i):
    """A point a kilometre or two from the centre, deterministic per index."""
    rnd = random.Random(i * 7919)
    # ~0.01 degrees is roughly a kilometre here.
    return (CENTRE_LAT + rnd.uniform(-0.03, 0.03),
            CENTRE_LNG + rnd.uniform(-0.03, 0.03))


def professions(api):
    status, body, _ = api.call("GET", "/organiser/get-home-screen-professions")
    if status != 200:
        return []
    payload = body.get("payload") or []
    return [p for p in payload if isinstance(p, dict) and p.get("id")]


def seed():
    print("Seeding %s" % BASE)

    catalog = None
    created = 0

    for i, (name, email) in enumerate(PEOPLE):
        phone = "%s%04d" % (PHONE_PREFIX, 9000 + i)
        api = Api()
        print(" - %s (%s)" % (name, phone))
        if not api.sign_in(phone, name, email):
            continue

        if catalog is None:
            catalog = professions(api)
            if not catalog:
                sys.exit("   ! no professions on the server — nothing to post against")
            print("   %d professions in the catalog" % len(catalog))

        lat, lng = scatter(i)
        status, body, _ = api.call("POST", "/authenticated/add-address", {
            "addressTitle": "%s home" % name.split()[0],
            "addressType": "HOME",
            "addressLine1": "House %d, Demo Colony" % (i + 1),
            "addressLine2": "Near the water tank",
            "city": "Bijnor",
            "state": "Uttar Pradesh",
            "postalCode": "246701",
            "latitude": "%.6f" % lat,
            "longitude": "%.6f" % lng,
            "pickedAddress": "Demo Colony, Bijnor, Uttar Pradesh",
        })
        if status != 200:
            print("   ! address: %s" % body.get("message"))
            continue

        status, body, _ = api.call("GET", "/authenticated/get-user-address")
        addresses = body.get("payload") or []
        if not addresses:
            print("   ! no address came back")
            continue
        address_id = str(addresses[0].get("id"))

        # Two jobs each, in different professions, so the Earning Zone has a
        # spread rather than eight of the same thing.
        for n in range(2):
            title, description = JOBS[(i * 2 + n) % len(JOBS)]
            profession = catalog[(i * 3 + n) % len(catalog)]
            # Open to quotes rather than instant: it is the path with more
            # screens behind it, so it exercises more of the app.
            status, body, _ = api.call("POST", "/organiser/post-new-job", {
                "title": "%s %s" % (DEMO_TAG, title),
                "description": description,
                "professionId": profession["id"],
                "addressId": address_id,
                "quoteType": "OPEN",
                "hireMode": "SCHEDULED",
                "repeatType": "ONCE",
                "openForDays": 7,
                "workersNeeded": 1,
                "payUnit": "DAY",
                "scheduleList": [{
                    "fullDate": (datetime.now() + timedelta(days=2 + n)).strftime(
                        "%Y-%m-%dT08:00:00"),
                    "slots": ["A_0845_1000"],
                }],
            })
            if status == 200:
                created += 1
            else:
                print("   ! job '%s': %s" % (title, body.get("message")))

    print()
    print("Created %d demo job(s) across %d account(s)." % (created, len(PEOPLE)))
    print("Sign in on your own number and open Earning Zone to see them.")
    print()
    print("⚠️  Remove with: python deploy/demo-data.py --teardown")


def teardown():
    """Delete every demo account, which takes its jobs with it."""
    print("Removing demo data from %s" % BASE)
    for i, (name, email) in enumerate(PEOPLE):
        phone = "%s%04d" % (PHONE_PREFIX, 9000 + i)
        api = Api()
        if not api.sign_in(phone, name, email):
            print(" - %s: not there" % phone)
            continue
        status, body, _ = api.call("POST", "/authenticated/delete-my-account", {})
        print(" - %s: %s" % (phone, "deleted" if status == 200 else body.get("message")))
    print()
    print("⚠️  Account deletion is a 180-day retention window, not an instant")
    print("    purge — the nightly sweep clears the rest. Jobs disappear now.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--teardown", action="store_true",
                        help="remove the demo accounts and their jobs")
    args = parser.parse_args()
    teardown() if args.teardown else seed()
