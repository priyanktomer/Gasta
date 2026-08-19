-- A full dataset in one command (PLAN-5 Phase 1 step 3).
--
--   mysql -u root -p gasta < scripts/seed.sql     -- load
--   mysql -u root -p gasta < scripts/reset.sql    -- remove
--
-- WHY. Every verification in this project used to begin with hand-written
-- INSERTs that then had to be cleaned up, which is why some scenarios never got
-- tested at all -- a half-filled crew job and an advance awaiting agreement are
-- both several joined rows, and nobody types those twice. This is that work done
-- once, and it is the difference between "I checked the register" and "I checked
-- the register with an advance the earner has not agreed to yet".
--
-- WHAT IT MAKES. One organiser, three earners, a household with members, tasks
-- in every state, a half-filled crew job, a doorstep provider on a non-laundry
-- profession, and an advance awaiting agreement.
--
-- EVERY ROW IS PREFIXED `seed:`. That is what makes reset.sql able to remove
-- exactly this and nothing else, and it is why the names read oddly. It matters
-- because this is meant to be run against a development database that already
-- holds the real catalog -- which exists in no migration and no file, only in
-- databases that have been in use, so a reset that took it out could not put it
-- back.
--
-- SAFE TO RE-RUN. Loading twice is a no-op rather than a duplicate: the script
-- deletes its own rows first. Everything is one transaction, so a failure
-- half way leaves nothing behind.
--
-- WHAT IT DELIBERATELY DOES NOT DO. It does not create the catalog. Professions,
-- sub-professions and service variants belong to the product, not to a test
-- fixture, and inventing a second copy here would be a second source of truth
-- that drifts. The seed makes its own profession rows, prefixed like everything
-- else.
--
-- PASSWORDS. Every seeded user has PASSWORD = '!' and no row in `users`, so none
-- of them can be logged into with a password. Sign in as them the way the app
-- does -- OTP on the phone number, which is the same string as the username.

SET autocommit = 0;
START TRANSACTION;

-- ── Clean up a previous load ────────────────────────────────────────────────
-- Inlined rather than sourced: `mysql < file` cannot include another file
-- portably, and a seed that only works when you remember to reset first is a
-- seed that will one day double every row.

DELETE FROM task_job          WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM task_schedule     WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM task_quote        WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM task_assignment   WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM cash_advance      WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM task              WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM pickup_drop_order_item WHERE ORDER_ID IN (SELECT ID FROM pickup_drop_order WHERE CUSTOMER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM pickup_drop_order      WHERE CUSTOMER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM doorstep_service_rate  WHERE PROVIDER_ID IN (SELECT ID FROM doorstep_provider WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM doorstep_provider      WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM household_member  WHERE OWNER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%') OR MEMBER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM earner_connection WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%') OR EARNER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM user_reputation   WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM notification      WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM app_user_address  WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM profession        WHERE NAME LIKE 'seed:%';
DELETE FROM app_users         WHERE USERNAME LIKE 'seed:%';

-- ── People ──────────────────────────────────────────────────────────────────
-- Phone numbers are in the 9999xxxxxx range, which is real-looking but reserved
-- here by convention; the username is the same string so that OTP sign-in works
-- the way the app expects.
INSERT INTO app_users (USERNAME, PHONE, FULL_NAME, PASSWORD, ENABLED,
                       ACCOUNT_NON_EXPIRED, ACCOUNT_NON_LOCKED, CREDENTIALS_NON_EXPIRED) VALUES
  ('seed:9999000001', '9999000001', 'seed: Meena (organiser)',      '!', TRUE, TRUE, TRUE, TRUE),
  ('seed:9999000002', '9999000002', 'seed: Sunita (earner)',        '!', TRUE, TRUE, TRUE, TRUE),
  ('seed:9999000003', '9999000003', 'seed: Kamla (earner)',         '!', TRUE, TRUE, TRUE, TRUE),
  ('seed:9999000004', '9999000004', 'seed: Ramesh (earner, crew)',  '!', TRUE, TRUE, TRUE, TRUE),
  -- The household member. §7.10 widened exactly one organiser check to let this
  -- person confirm a visit; the authorisation matrix in III.D.3 is about what
  -- they must still NOT be able to do, and it needs this row to test against.
  ('seed:9999000005', '9999000005', 'seed: Anil (household member)','!', TRUE, TRUE, TRUE, TRUE),
  -- Registered on a profession that is not laundry -- the case that was
  -- impossible until V8 and V9.
  ('seed:9999000006', '9999000006', 'seed: Vijay (doorstep)',       '!', TRUE, TRUE, TRUE, TRUE);

SET @organiser := (SELECT ID FROM app_users WHERE USERNAME = 'seed:9999000001');
SET @sunita    := (SELECT ID FROM app_users WHERE USERNAME = 'seed:9999000002');
SET @kamla     := (SELECT ID FROM app_users WHERE USERNAME = 'seed:9999000003');
SET @ramesh    := (SELECT ID FROM app_users WHERE USERNAME = 'seed:9999000004');
SET @anil      := (SELECT ID FROM app_users WHERE USERNAME = 'seed:9999000005');
SET @vijay     := (SELECT ID FROM app_users WHERE USERNAME = 'seed:9999000006');

-- ── Where ───────────────────────────────────────────────────────────────────
-- Pundri Kalan, matching `adb emu geo fix 78.18 29.59` in PLAN-5 §I.2, so the
-- emulator's location puts these jobs in range without anybody moving the pin.
--
-- app_user_address.STATE is a foreign key to location_state.CODE. That is not
-- visible from the column's name or its type and is found by the insert failing,
-- so the state is ensured first.
INSERT INTO location_country (CODE, NAME)
SELECT 'IN', 'India' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM location_country WHERE CODE = 'IN');

-- Attributed to the audit actor V1__baseline.sql seeds, NOT to the seed's own
-- organiser. location_state.UPDATED_BY is a NOT NULL foreign key to app_users,
-- so pointing it at a seeded user makes reset.sql fail on a constraint naming a
-- table it never touches:
--
--     ERROR 1451: Cannot delete or update a parent row: a foreign key
--     constraint fails (`location_state`, CONSTRAINT ... FOREIGN KEY
--     (`UPDATED_BY`) REFERENCES `app_users` (`ID`))
--
-- Reference data must outlive the fixture that needed it.
SET @system := (SELECT ID FROM app_users WHERE USERNAME = 'system-migration');

INSERT INTO location_state (CODE, NAME, COUNTRY_CODE, IS_ENABLED, CREATED_DATE, UPDATED_DATE, UPDATED_BY)
SELECT 'UT', 'Uttarakhand', 'IN', TRUE, NOW(), NOW(), COALESCE(@system, @organiser) FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM location_state WHERE CODE = 'UT' AND COUNTRY_CODE = 'IN');

-- Slightly north of the emulator's fix, not on top of it: the nearby-jobs query
-- ends `HAVING distanceKm > :minDistance` and the widest band's floor is 0, so a
-- job at exactly the searched coordinates is excluded by 0 > 0.
INSERT INTO app_user_address (USER_ID, ADDRESS_LINE1, ADDRESS_LINE2, CITY, STATE,
                              LATITUDE, LONGITUDE, CREATED_DATE, UPDATED_DATE)
VALUES (@organiser, 'seed: House 12', 'seed: Main Bazaar', 'Pundri Kalan', 'UT',
        29.6000, 78.1800, NOW(), NOW());
SET @address := LAST_INSERT_ID();

-- ── The catalog rows this seed owns ─────────────────────────────────────────
INSERT INTO profession (NAME, CATEGORY, DESCRIPTION, IS_ENABLED, SUPPORTS_PICKUP_DROP,
                        MULTI_SELECT_SUB_PROFESSIONS, ALLOWS_ONE_OFF, MULTI_SELECT_SLOTS,
                        CREATED_DATE, UPDATED_DATE, UPDATED_BY) VALUES
  ('seed: Housemaid',          'DOMESTIC',   'Daily cleaning and dishes', TRUE, FALSE, FALSE, TRUE, FALSE, NOW(), NOW(), @organiser),
  ('seed: Farm hand',          'AGRICULTURE','Seasonal field work',       TRUE, FALSE, FALSE, TRUE, FALSE, NOW(), NOW(), @organiser),
  ('seed: Appliance mechanic', 'MECHANICAL', 'Repairs at the door',       TRUE, TRUE,  FALSE, TRUE, FALSE, NOW(), NOW(), @organiser);

SET @maid     := (SELECT ID FROM profession WHERE NAME = 'seed: Housemaid');
SET @farm     := (SELECT ID FROM profession WHERE NAME = 'seed: Farm hand');
SET @mechanic := (SELECT ID FROM profession WHERE NAME = 'seed: Appliance mechanic');

-- ── The household (§7.10) ───────────────────────────────────────────────────
INSERT INTO household_member (OWNER_ID, MEMBER_ID, ACTIVE, CREATED_DATE)
VALUES (@organiser, @anil, TRUE, NOW());

-- ── Tasks, one per state ────────────────────────────────────────────────────
-- OPEN: on the board, quotable, nobody assigned. This is what an earner browsing
-- the Earning Zone should see.
INSERT INTO task (TITLE, DESCRIPTION, QUOTE_TYPE, PAY_UNIT, IS_ACTIVE, IS_OPEN_TO_QUOTE,
                  IS_FEEDBACK_PROVIDED, IS_PART_DRAWN, WORKERS_NEEDED, IS_INSTANT_HIRE,
                  CREW_ALL_OR_NOTHING, ADDRESS_ID, ORGANISER_ID, PROFESSION_ID, UPDATED_BY,
                  CREATED_DATE, UPDATED_DATE)
VALUES ('seed: Morning cleaning, open', 'Two rooms and dishes, six mornings a week',
        'OPEN', 'MONTH', TRUE, TRUE, FALSE, FALSE, 1, FALSE, FALSE,
        @address, @organiser, @maid, @organiser, NOW(), NOW());
SET @task_open := LAST_INSERT_ID();

-- RUNNING: assigned to Sunita, with a schedule and visits either side of today.
-- The dates are the point. Earnings once counted past-dated visits as future
-- income -- "still to come: 67 days" included 31 that had already happened -- so
-- a fixture with visits only in the future cannot catch it coming back.
INSERT INTO task (TITLE, DESCRIPTION, QUOTE_TYPE, PAY_UNIT, IS_ACTIVE, IS_OPEN_TO_QUOTE,
                  IS_FEEDBACK_PROVIDED, IS_PART_DRAWN, WORKERS_NEEDED, IS_INSTANT_HIRE,
                  CREW_ALL_OR_NOTHING, ADDRESS_ID, ORGANISER_ID, PROFESSION_ID, UPDATED_BY,
                  CREATED_DATE, UPDATED_DATE)
VALUES ('seed: Daily cleaning, running', 'The engagement the register is about',
        'FIXED', 'MONTH', TRUE, FALSE, FALSE, FALSE, 1, FALSE, FALSE,
        @address, @organiser, @maid, @organiser, NOW(), NOW());
SET @task_running := LAST_INSERT_ID();

INSERT INTO task_assignment (TASK_ID, EARNER_ID, CREW_SIZE, IS_ACTIVE, ASSIGNED_AT)
VALUES (@task_running, @sunita, 1, TRUE, NOW() - INTERVAL 40 DAY);

INSERT INTO task_schedule (TASK_ID, ORGANISER_ID, EARNER_ID, REPEAT_TYPE, DAY, SLOT_1,
                           IS_ACTIVE, CREATED_DATE)
VALUES (@task_running, @organiser, @sunita, 'REPEAT_DAILY', 'ALL', 'A_0600_0730',
        TRUE, NOW() - INTERVAL 40 DAY);
SET @schedule := LAST_INSERT_ID();

-- Three visits: one done and in the past, one today, one still to come.
INSERT INTO task_job (TASK_ID, TASK_SCHEDULE_ID, ORGANISER_ID, EARNER_ID, OCCURRENCE_DATE,
                      STATUS, IS_COMPLETED, IS_CANCELED, IS_STARTED, HAS_ARRIVED,
                      CREATED_DATE, UPDATED_DATE, UPDATED_BY) VALUES
  (@task_running, @schedule, @organiser, @sunita, CURDATE() - INTERVAL 2 DAY,
   'COMPLETED', TRUE,  FALSE, TRUE,  TRUE,  NOW(), NOW(), @organiser),
  (@task_running, @schedule, @organiser, @sunita, CURDATE(),
   'SCHEDULED',  FALSE, FALSE, FALSE, FALSE, NOW(), NOW(), @organiser),
  (@task_running, @schedule, @organiser, @sunita, CURDATE() + INTERVAL 2 DAY,
   'SCHEDULED',  FALSE, FALSE, FALSE, FALSE, NOW(), NOW(), @organiser);

-- QUOTED: Kamla has quoted and is waiting for an answer.
INSERT INTO task (TITLE, DESCRIPTION, QUOTE_TYPE, PAY_UNIT, IS_ACTIVE, IS_OPEN_TO_QUOTE,
                  IS_FEEDBACK_PROVIDED, IS_PART_DRAWN, WORKERS_NEEDED, IS_INSTANT_HIRE,
                  CREW_ALL_OR_NOTHING, ADDRESS_ID, ORGANISER_ID, PROFESSION_ID, UPDATED_BY,
                  CREATED_DATE, UPDATED_DATE)
VALUES ('seed: Evening dishes, quoted', 'One quote in, no answer yet',
        'OPEN', 'MONTH', TRUE, TRUE, FALSE, FALSE, 1, FALSE, FALSE,
        @address, @organiser, @maid, @organiser, NOW(), NOW());
SET @task_quoted := LAST_INSERT_ID();

INSERT INTO task_quote (TASK_ID, EARNER_ID, ORGANISER_ID, QUOTE_AMOUNT, IS_ACCEPTED,
                        IS_REJECTED, IS_REVOKED, CREATED_DATE, UPDATED_DATE, UPDATED_BY)
VALUES (@task_quoted, @kamla, @organiser, 2500, FALSE, FALSE, FALSE, NOW(), NOW(), @kamla);

-- ENDED: closed out, so the register has a finished engagement to show.
INSERT INTO task (TITLE, DESCRIPTION, QUOTE_TYPE, PAY_UNIT, IS_ACTIVE, IS_OPEN_TO_QUOTE,
                  IS_FEEDBACK_PROVIDED, IS_PART_DRAWN, WORKERS_NEEDED, IS_INSTANT_HIRE,
                  CREW_ALL_OR_NOTHING, ADDRESS_ID, ORGANISER_ID, PROFESSION_ID, UPDATED_BY,
                  CREATED_DATE, UPDATED_DATE)
VALUES ('seed: Last season harvest, ended', 'Finished engagement',
        'FIXED', 'DAY', FALSE, FALSE, TRUE, FALSE, 1, FALSE, FALSE,
        @address, @organiser, @farm, @organiser, NOW() - INTERVAL 200 DAY, NOW() - INTERVAL 120 DAY);

-- PARTLY FILLED CREW (§7.11): six of ten, all-or-nothing, so the organiser has
-- the "go ahead or release?" decision waiting. CREW_SIZE is people, not rows --
-- COUNT(*) once reported a crew of six as 1 of 10 and left nine places
-- apparently free.
INSERT INTO task (TITLE, DESCRIPTION, QUOTE_TYPE, PAY_UNIT, IS_ACTIVE, IS_OPEN_TO_QUOTE,
                  IS_FEEDBACK_PROVIDED, IS_PART_DRAWN, WORKERS_NEEDED, IS_INSTANT_HIRE,
                  CREW_ALL_OR_NOTHING, ADDRESS_ID, ORGANISER_ID, PROFESSION_ID, UPDATED_BY,
                  CREATED_DATE, UPDATED_DATE)
VALUES ('seed: Wheat cutting, crew of ten', 'Ten people for one day, all or nothing',
        'FIXED', 'DAY', TRUE, TRUE, FALSE, FALSE, 10, FALSE, TRUE,
        @address, @organiser, @farm, @organiser, NOW(), NOW());
SET @task_crew := LAST_INSERT_ID();

INSERT INTO task_assignment (TASK_ID, EARNER_ID, CREW_SIZE, IS_ACTIVE, ASSIGNED_AT)
VALUES (@task_crew, @ramesh, 6, TRUE, NOW());

-- ── An advance awaiting agreement (§7.2) ────────────────────────────────────
-- Recorded by the organiser, not yet agreed by the earner. This is the state the
-- ledger sheet is for and the one that shipped without a `respond-advance`
-- endpoint, stranding both sides.
--
-- GIVEN_ON is a DATE. It serialised as [2026,8,10] once and the advances sheet
-- would not open -- the app parsed it as a List. Anything reading this row is
-- also testing the JSON shape.
INSERT INTO cash_advance (TASK_ID, ORGANISER_ID, EARNER_ID, RECORDED_BY, AMOUNT,
                          GIVEN_ON, NOTE, CREATED_DATE)
VALUES (@task_running, @organiser, @sunita, @organiser, 2000,
        CURDATE() - INTERVAL 10 DAY, 'seed: for her daughter''s school fee', NOW());

-- ── Doorstep, on a profession that is not laundry ───────────────────────────
-- Registering this was impossible before V8 and V9: SERVICE_TYPE is a laundry
-- concept, the entity leaves it null everywhere else, and the column was NOT
-- NULL. The rate below has no service type on purpose.
INSERT INTO doorstep_provider (USER_ID, PROFESSION_ID, BIO, SERVICE_PINCODES,
                               LATITUDE, LONGITUDE, MAX_ORDERS_PER_DAY,
                               IS_ACTIVE, CREATED_DATE, UPDATED_DATE)
VALUES (@vijay, @mechanic, 'seed: Fans, coolers, mixers', '247001',
        29.6000, 78.1800, 5, TRUE, NOW(), NOW());
SET @provider := LAST_INSERT_ID();

INSERT INTO doorstep_service_rate (PROVIDER_ID, ITEM_CATEGORY, SERVICE_TYPE,
                                   PRICE_PER_PIECE, IS_ACTIVE)
VALUES (@provider, 'seed: Ceiling fan', NULL, 250, TRUE);

COMMIT;
SET autocommit = 1;

SELECT 'seeded' AS result,
       (SELECT COUNT(*) FROM app_users WHERE USERNAME LIKE 'seed:%')            AS users,
       (SELECT COUNT(*) FROM task WHERE TITLE LIKE 'seed:%')                    AS tasks,
       (SELECT COUNT(*) FROM task_job WHERE TASK_ID IN
           (SELECT ID FROM task WHERE TITLE LIKE 'seed:%'))                     AS visits,
       (SELECT COUNT(*) FROM cash_advance WHERE NOTE LIKE 'seed:%')             AS advances;
