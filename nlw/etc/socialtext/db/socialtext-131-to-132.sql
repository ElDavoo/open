BEGIN;

-- Clean up old search codes
DROP TABLE search_set_workspaces;
DROP TABLE search_sets;

UPDATE "System"
   SET value = '132'
 WHERE field = 'socialtext-schema-version';

COMMIT;
