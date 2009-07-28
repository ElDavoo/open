BEGIN;

-- Add a type to accounts
ALTER TABLE "Account"
    ADD COLUMN "account_type" text NOT NULL DEFAULT 'Standard';

ALTER TABLE "Account"
    ADD COLUMN "restrict_to_domain" text NOT NULL DEFAULT '';

UPDATE "System"
   SET value = '76'
 WHERE field = 'socialtext-schema-version';

COMMIT;
