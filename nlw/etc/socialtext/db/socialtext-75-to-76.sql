BEGIN;

-- Add a type to accounts
ALTER TABLE "Account"
    ADD COLUMN "account_type" text NOT NULL DEFAULT 'Standard';

UPDATE "System"
   SET value = '76'
 WHERE field = 'socialtext-schema-version';

COMMIT;
