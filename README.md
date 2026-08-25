# Gasta — planning and design

Gasta connects rural and semi-urban Indian households and small farms with the
people who work for them: maids, cooks, farm labour, drivers, mechanics. **The
unit of the product is the relationship, not the transaction** — a maid who comes
every morning for three years, not a one-off booking. Almost every design
decision follows from that.

This repository holds the documents. The code lives beside it:

| Folder | Repository | What |
|---|---|---|
| `JeevikaService/` | [JeevikaService](https://github.com/priyanktomer/JeevikaService) | Spring Boot 3 / Java 17 / MySQL 8 backend |
| `Yapan/` | [yapan](https://github.com/priyanktomer/yapan) | Flutter app (`com.tomer.yapan`) |
| `access-app/` | [access-app](https://github.com/priyanktomer/access-app) | In-house auth library |
| `super-methods/` | [super-methods](https://github.com/priyanktomer/super-methods) | Shared response helpers |
| `mysql-multitenancy/` | [mysql-multitenancy](https://github.com/priyanktomer/mysql-multitenancy) | Datasource routing |

Clone them as siblings inside this folder and the paths in the plans work.

## Start here

| Document | Read it for |
|---|---|
| **PLAN-6.md** | **Start here.** What is outstanding after the first deployment — a draft, deliberately, waiting on the product owner's feedback from using the app before anything in it is ordered. |
| **OBSERVATIONS.md** | Defects and questions noticed while doing something else. Nothing here is scheduled; some are two-minute fixes and some are product decisions. Add to it rather than mentioning a thing once and losing it. |
| **PLAN-5.md** | **Historical — every phase is done or explicitly parked.** Fourteen phases from a safety net through consent, Hindi, the handover and deployment. Kept because it carries the *reasoning*: read it when you want to know why something is the way it is. |
| **PLAN-4.md** | The product thesis, the architecture, and the rules learned the hard way. §1–§4 are still current. |
| **PLAN-3.md** | The detailed history — every item's reasoning and every defect found. |
| **DESIGN-RULES.md** | Binding UI rules. |
| **AUDIT.md**, **DEFERRED.md**, **PLAN.md**, **PLAN-2.md** | Earlier phases, kept for provenance. |

**The backend is live** at https://yapan.duckdns.org — one Ampere A1 VM on
Oracle Cloud, TLS from Let's Encrypt, nightly backups that are verified by
restoring and copied off the host. The runbook is
[deploy/README.md](deploy/README.md).

The two things still waiting on a person rather than on code: **a lawyer** for
the six legal documents, which ship with DRAFT banners, and **a named Grievance
Officer**, which the IT Rules 2021 require.

## Two rules that override everything else

1. **Verify in the emulator.** Compiling is not evidence. Roughly a third of the
   defects in this project passed `flutter analyze` and `mvnw compile` cleanly.
2. **There is no "pre-existing" or "unrelated" bug.** Every defect found here is
   ours to fix, analyzer warnings included. Standing instruction from the product
   owner.
