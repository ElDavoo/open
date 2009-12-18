BEGIN;

CREATE TABLE page_plugin_pref (
    workspace_id BIGINT NOT NULL,
    page_id TEXT NOT NULL,
    plugin TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL
);

CREATE TABLE user_page_plugin_pref (
    user_id BIGINT NOT NULL,
    workspace_id BIGINT NOT NULL,
    page_id TEXT NOT NULL,
    plugin TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL
);

UPDATE "System"
   SET value = '101'
 WHERE field = 'socialtext-schema-version';

COMMIT;
