#!/usr/bin/env python3
"""Seed the server with demo data, so the app has something to show.

    python deploy/demo-data.py            # seed (safe to re-run)
    python deploy/demo-data.py --teardown # remove what it created

Every screen on a fresh server is empty, which makes the app impossible to
judge — you cannot tell a layout problem from a missing row.

⚠️ **This writes to the live database.** Everything it creates is deliberately
recognisable: accounts on 90000090xx, obviously fictional names, and job titles
prefixed `[demo]`. Tear it down before real users exist.

## Why the API and not SQL

Posting through the real endpoints means the rows are valid by construction —
schedules expand, addresses resolve to a state row, reputations initialise. A
hand-written INSERT would have to reproduce every rule in `OrganiserServiceImpl`
and would silently get some of them wrong, which is worse than no demo data
because it looks real.

It also means this script cannot create anything the app itself could not, which
is the property that makes it safe to point at production.

⚠️ It depends on the OTP being `000000` for every number, which is true today
and is tracked as O-18. **When SMS is wired this stops working**, and that is
the correct outcome — a tool that can create accounts on a production system is
not something to keep working.
"""

import argparse
import json
import random
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta

BASE = "https://yapan.duckdns.org/api/v1/yapan"

# ⚠️ **Seed near where the phone actually is, with `--near LAT,LNG`.**
#
# The Earning Zone's widest band, "Any", is 0-25 km — `DistanceBucket.VERY_LONG`
# tops out there. Jobs seeded further away than that are invisible no matter
# what the filter says, and the screen reads "No jobs found nearby" with no
# clue that the data exists. That happened: the first run seeded Bijnor while
# the test phone was 130 km away in Noida.
#
# The default below is only a starting point. Get the real one from a connected
# handset:
#
#     adb shell dumpsys location | grep -oE "[0-9.]+,[0-9.]+" | head -1
CENTRE_LAT = 28.5692
CENTRE_LNG = 77.4077

DEMO_TAG = "[demo]"

# Plainly fictional, and the roles this product is actually about.
PEOPLE = [
    ("9000009000", "Asha Demo", "gasta.demo.asha@gmail.com"),
    ("9000009001", "Ramesh Demo", "gasta.demo.ramesh@gmail.com"),
    ("9000009002", "Sunita Demo", "gasta.demo.sunita@gmail.com"),
    ("9000009003", "Imran Demo", "gasta.demo.imran@gmail.com"),
    ("9000009004", "Kavita Demo", "gasta.demo.kavita@gmail.com"),
]

# Titles that read like something a person would post. A screen full of
# "Test job 1" tells you nothing about whether the screen works.
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


def _json_body(raw):
    try:
        return json.loads(raw.decode() or "{}")
    except ValueError:
        return {"message": raw.decode(errors="replace")[:200]}


def _headers(headers):
    """Lower-cased keys.

    ⚠️ HTTP header names are case-insensitive but `dict()` is not, and the
    server sends `Authorization`. Reading `authorization` off the raw dict made
    a *successful* sign-up look like a failure.
    """
    return {k.lower(): v for k, v in dict(headers).items()}


class Api:
    """Enough HTTP for this script, with no dependencies."""

    def __init__(self):
        self.auth = None
        self.atsh = None

    def call(self, method, path, body=None, public=False):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(BASE + path, data=data, method=method)
        req.add_header("Content-Type", "application/json")
        if not public:
            if not self.auth:
                raise RuntimeError("not signed in")
            req.add_header("Authorization", self.auth)
            req.add_header("atsh", self.atsh)
        try:
            with urllib.request.urlopen(req, timeout=30) as res:
                return res.status, _json_body(res.read()), _headers(res.headers)
        except urllib.error.HTTPError as e:
            return e.code, _json_body(e.read()), _headers(e.headers)

    def sign_in(self, phone, full_name, email):
        """Sign in, signing up first if the account is new."""
        self.call("POST", "/common/otp-request", {"phone": phone}, public=True)

        status, body, headers = self.call(
            "POST", "/common/login-verify", {"phone": phone, "otp": "000000"},
            public=True)
        if not headers.get("authorization"):
            status, body, headers = self.call(
                "POST", "/common/sign-up-verify",
                {"fullName": full_name, "phone": phone, "email": email,
                 "otp": "000000"},
                public=True)
        if not headers.get("authorization"):
            print("   ! %s: %s" % (phone, body.get("message")))
            # ⚠️ "Too many wrong codes" means the OTP-verify limiter (five per
            # phone per fifteen minutes) has been tripped by re-running this
            # script, not that anything is broken. Wait a quarter of an hour.
            return False
        self.auth = headers["authorization"]
        self.atsh = headers.get("atsh")
        return True


def scatter(i, centre):
    """A point a kilometre or three from the centre, stable per person."""
    rnd = random.Random(i * 7919)
    # ~0.01 degrees is roughly a kilometre at this latitude.
    return (centre[0] + rnd.uniform(-0.03, 0.03),
            centre[1] + rnd.uniform(-0.03, 0.03))


def state_code(api, want="uttar pradesh"):
    """The code `location_state` stores, not the display name.

    ⚠️ `addAddress` looks the state up by **code** and stores null when it does
    not match — so posting "Uttar Pradesh" silently saves an address with no
    state. Asking the server which codes exist is the only way to be right.
    """
    status, body, _ = api.call("GET", "/authenticated/get-states?countryCode=IND")
    states = (body.get("payload") or []) if status == 200 else []
    for st in states:
        if str(st.get("name", "")).strip().lower() == want:
            return st.get("code")
    if states:
        print("   ! '%s' not found; using %s" % (want, states[0].get("name")))
        return states[0].get("code")
    return None


def professions(api):
    status, body, _ = api.call("GET", "/organiser/get-home-screen-professions")
    payload = (body.get("payload") or []) if status == 200 else []
    return [p for p in payload if isinstance(p, dict) and p.get("id")]


def ensure_address(api, name, index, state, centre, city):
    """This person's address id near `centre`, creating one if there is none.

    Idempotent per location: re-running with the same `--near` reuses the
    address it made last time, and re-running with a different one adds a new
    address rather than leaving the jobs stranded 130 km away.
    """
    lat, lng = scatter(index, centre)
    # The title carries the coordinates so "is there already one here?" is
    # answerable without geometry.
    title = "%s home (%.3f,%.3f)" % (name.split()[0], lat, lng)

    status, body, _ = api.call("GET", "/authenticated/get-user-address")
    existing = (body.get("payload") or []) if status == 200 else []
    for addr in existing:
        if str(addr.get("addressTitle")) == title:
            return str(addr.get("id"))

    status, body, _ = api.call("POST", "/authenticated/add-address", {
        "addressTitle": title,
        "addressType": "HOME",
        "addressLine1": "House %d, Demo Colony" % (index + 1),
        "addressLine2": "Near the water tank",
        # ⚠️ Passed in, not hardcoded. The first run said "Bijnor" while the
        # coordinates were in Noida, and the job cards duly showed a town
        # 130 km from the pin — demo data that lies about itself is worse than
        # none, because it looks like a bug in the app.
        "city": city,
        "state": state,
        "postalCode": "246701",
        "latitude": "%.6f" % lat,
        "longitude": "%.6f" % lng,
        "pickedAddress": "Demo Colony, %s, Uttar Pradesh" % city,
    })
    if status != 200:
        print("   ! address: %s" % body.get("message"))
        return None

    status, body, _ = api.call("GET", "/authenticated/get-user-address")
    addresses = (body.get("payload") or []) if status == 200 else []
    for addr in addresses:
        if str(addr.get("addressTitle")) == title:
            return str(addr.get("id"))
    return None


def post_jobs(api, catalog, address_id, index):
    """Two jobs in different professions, so the list has a spread."""
    posted = 0
    for n in range(2):
        title, description = JOBS[(index * 2 + n) % len(JOBS)]
        profession = catalog[(index * 3 + n) % len(catalog)]
        # Open to quotes rather than instant: more of the app sits behind that
        # path, so it exercises more screens.
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
                # ⚠️ `NewTaskSchedule.fullDate` carries
                # @JsonFormat("yyyy-MM-dd HH:mm:ss.SSS"), so ISO-8601 with a 'T'
                # is rejected — and Spring answers "The request could not be
                # read", which says nothing about which field is wrong.
                "fullDate": (datetime.now() + timedelta(days=2 + n)).strftime(
                    "%Y-%m-%d 08:00:00.000"),
                "slots": ["A_0845_1000"],
            }],
        })
        if status == 200:
            posted += 1
        else:
            print("   ! job '%s': %s" % (title, body.get("message")))
    return posted


# Short, plain, and within QuoteDto's 60-character pattern — no symbols beyond
# `.,!?:()-` or the whole request is rejected.
QUOTE_MESSAGES = [
    "I can come at the time you said.",
    "I have done this work for many years.",
    "I will bring my own tools.",
    "Available from tomorrow morning.",
    "Price is for the full day.",
]


def build_scenario(apis, centre):
    """Quote, accept, and leave the demo accounts with full screens.

    Seeding jobs alone fills exactly one screen — Earning Zone. Everything
    else in the product is downstream of somebody *responding* to a job:
    quotes received, the dashboard counts, today's visits, the register, and
    the notifications each of those sends.

    So the demo accounts do to each other what real users would: everybody
    browses, quotes on what they did not post, and every organiser accepts one
    of the quotes they got.
    """
    quoted = accepted = 0

    # ── Everyone quotes on a couple of other people's jobs ───────────────
    for phone, api in apis.items():
        status, body, _ = api.call("POST", "/earner/get-nearby-jobs", {
            "latitude": "%.6f" % centre[0], "longitude": "%.6f" % centre[1],
        })
        jobs = (body.get("payload") or []) if status == 200 else []
        # `get-nearby-jobs` already excludes the caller's own jobs and any they
        # have quoted on, so whatever comes back is fair game.
        for n, job in enumerate(jobs[:2]):
            status, body, _ = api.call("POST", "/earner/add-task-quote", {
                "taskId": job.get("id"),
                "amt": 400 + 50 * ((n + len(phone)) % 8),
                "msg": QUOTE_MESSAGES[(n + len(phone)) % len(QUOTE_MESSAGES)],
            })
            if status == 200:
                quoted += 1
            else:
                print("   ! quote on %s: %s" % (job.get("id"), body.get("message")))

    # ── Every organiser accepts one quote on one of their jobs ───────────
    #
    # One, not all: a job with places still open is as much a part of the
    # picture as a filled one, and the dashboard is meant to show both.
    for phone, api in apis.items():
        status, body, _ = api.call("GET", "/organiser/get-my-posted-tasks")
        tasks = (body.get("payload") or []) if status == 200 else []
        for task in tasks[:1]:
            task_id = task.get("id")
            status, body, _ = api.call("GET",
                                       "/organiser/get-quotes-for-task/%s" % task_id)
            quotes = (body.get("payload") or []) if status == 200 else []
            if not quotes:
                continue
            quote_id = quotes[0].get("id")
            status, body, _ = api.call("POST",
                                       "/organiser/accept-quote/%s" % quote_id)
            if status == 200:
                accepted += 1
            else:
                print("   ! accept %s: %s" % (quote_id, body.get("message")))

    return quoted, accepted


def seed(centre, city):
    print("Seeding %s" % BASE)
    print("Centre: %.4f, %.4f  (jobs land within ~3 km of this)" % centre)
    catalog = None
    state = None
    created = 0
    # Kept signed in, so the scenario below can act as each of them without
    # signing in again — every extra login costs one of the five OTP attempts
    # the limiter allows per phone per fifteen minutes.
    signed_in = {}

    for index, (phone, name, email) in enumerate(PEOPLE):
        api = Api()
        print(" - %s (%s)" % (name, phone))
        if not api.sign_in(phone, name, email):
            continue

        if catalog is None:
            catalog = professions(api)
            if not catalog:
                sys.exit("   ! no professions on the server - nothing to post against")
            print("   %d professions in the catalog" % len(catalog))
        if state is None:
            state = state_code(api)
            if not state:
                sys.exit("   ! no states on the server - addresses cannot be saved")
            print("   state code: %s" % state)

        address_id = ensure_address(api, name, index, state, centre, city)
        if address_id:
            created += post_jobs(api, catalog, address_id, index)
            signed_in[phone] = api

    print()
    print("Posted %d demo job(s)." % created)

    if signed_in:
        print("Building the rest of the picture...")
        quoted, accepted = build_scenario(signed_in, centre)
        print("  %d quote(s) placed, %d accepted." % (quoted, accepted))
    print()
    print("To see every screen with data, sign in as one of the demo accounts:")
    print("    %s   OTP 000000" % PEOPLE[1][0])
    print("They have posted work, received quotes, accepted one, and have a")
    print("visit scheduled - so Dashboard, Today and Notifications are not empty.")
    print()
    print("Your own account still sees the jobs in Earning Zone, from within")
    print("25 km of the centre above.")
    print()
    # Plain ASCII throughout: a Windows console is cp1252 and cannot encode a
    # warning glyph, which would crash the script *after* it had written to the
    # live database.
    print("!! Remove with: python deploy/demo-data.py --teardown")


def teardown():
    """Delete every demo account, which takes its jobs with it."""
    print("Removing demo data from %s" % BASE)
    for phone, name, email in PEOPLE:
        api = Api()
        if not api.sign_in(phone, name, email):
            print(" - %s: not there" % phone)
            continue
        status, body, _ = api.call("POST", "/authenticated/delete-my-account", {})
        print(" - %s: %s" % (phone, "deleted" if status == 200 else body.get("message")))
    print()
    print("!! Account deletion honours the 180-day retention window rather than")
    print("   purging immediately - the nightly sweep clears the rest. The jobs")
    print("   disappear from the app straight away, which is what matters here.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed or remove demo data.")
    parser.add_argument("--teardown", action="store_true",
                        help="remove the demo accounts and their jobs")
    parser.add_argument("--near", metavar="LAT,LNG",
                        help="seed around this point instead of the default; "
                             "jobs more than 25 km from the phone are invisible")
    parser.add_argument("--city", default="Demo Nagar",
                        help="the town the demo addresses claim to be in; set "
                             "it to match --near or the cards will say one "
                             "place while the pin is in another")
    args = parser.parse_args()
    if args.teardown:
        teardown()
    else:
        point = (CENTRE_LAT, CENTRE_LNG)
        if args.near:
            lat, _, lng = args.near.partition(",")
            point = (float(lat), float(lng))
        seed(point, args.city)
