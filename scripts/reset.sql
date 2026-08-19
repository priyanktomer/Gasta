-- Removes everything scripts/seed.sql created, and nothing else.
--
--   mysql -u root -p gasta < scripts/reset.sql
--
-- WHY THIS IS NOT `DROP DATABASE`. The seed runs against a database that also
-- holds the catalog -- professions, sub-professions, service variants, states --
-- and the catalog is not in the seed and is not in any migration either. It
-- exists only in databases that have been in use. Dropping the schema to clean
-- up test data would take the catalog with it and there is no file to put it
-- back from. So this deletes by ownership instead.
--
-- ORDER IS FORCED BY THE FOREIGN KEYS. Children before parents, and app_users
-- last of all -- twelve tables reference it. Getting this wrong does not corrupt
-- anything, it just fails with a constraint name that does not obviously belong
-- to the row you were deleting.
--
-- Safe to run twice, and safe to run against a database that has never been
-- seeded: every statement is a DELETE with a WHERE that matches nothing.

-- The users the seed owns. Everything else is found through them, so a row the
-- seed created but this script does not name still goes, as long as it hangs off
-- one of these.
--
-- Written as a repeated subquery rather than a temporary table. The tidier
-- version collected the ids into a TEMPORARY TABLE once; MySQL then refuses the
-- household_member and earner_connection deletes with
--
--     ERROR 1137 (HY000): Can't reopen table: '_seed_users'
--
-- because a temporary table may not be referenced twice in one statement, and
-- both of those match on two columns. A plain base table has no such limit.

-- Visits and the things attached to them.
DELETE FROM task_job          WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM task_schedule     WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM task_quote        WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM task_assignment   WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM cash_advance      WHERE TASK_ID IN (SELECT ID FROM task WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM task              WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');

-- Doorstep.
DELETE FROM pickup_drop_order_item WHERE ORDER_ID IN (SELECT ID FROM pickup_drop_order WHERE CUSTOMER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM pickup_drop_order      WHERE CUSTOMER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM doorstep_service_rate  WHERE PROVIDER_ID IN (SELECT ID FROM doorstep_provider WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%'));
DELETE FROM doorstep_provider      WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');

-- Relationships and per-user records.
DELETE FROM household_member  WHERE OWNER_ID  IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%')
                                 OR MEMBER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM earner_connection WHERE ORGANISER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%')
                                 OR EARNER_ID    IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM user_reputation   WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM notification      WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');
DELETE FROM app_user_address  WHERE USER_ID IN (SELECT ID FROM app_users WHERE USERNAME LIKE 'seed:%');

-- The seed's own profession rows. Named rather than found by ownership: the
-- catalog's real professions are also UPDATED_BY somebody, and deleting those
-- would empty the catalog this script exists to protect.
DELETE FROM profession WHERE NAME LIKE 'seed:%';

-- Last.
DELETE FROM app_users WHERE USERNAME LIKE 'seed:%';


SELECT CONCAT('seed rows remaining: ',
              (SELECT COUNT(*) FROM app_users WHERE USERNAME LIKE 'seed:%')) AS result;
