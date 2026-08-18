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
| **PLAN-5.md** | **What to do next.** The current entry point. |
| **PLAN-4.md** | The product thesis, the architecture, and the rules learned the hard way. §1–§4 are still current. |
| **PLAN-3.md** | The detailed history — every item's reasoning and every defect found. |
| **DESIGN-RULES.md** | Binding UI rules. |
| **AUDIT.md**, **DEFERRED.md**, **PLAN.md**, **PLAN-2.md** | Earlier phases, kept for provenance. |

## Two rules that override everything else

1. **Verify in the emulator.** Compiling is not evidence. Roughly a third of the
   defects in this project passed `flutter analyze` and `mvnw compile` cleanly.
2. **There is no "pre-existing" or "unrelated" bug.** Every defect found here is
   ours to fix, analyzer warnings included. Standing instruction from the product
   owner.
