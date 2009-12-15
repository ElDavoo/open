BEGIN;

-- Migrate signal_account table to signal_user_set to enable
-- Signal to Groups

CREATE TABLE signal_user_set (
    signal_id bigint NOT NULL,
    user_set_id int NOT NULL
);

ALTER TABLE ONLY signal_user_set
    ADD CONSTRAINT signal_user_set_pkey
            PRIMARY KEY (signal_id, user_set_id);

ALTER TABLE ONLY signal_user_set
    ADD CONSTRAINT signal_user_set_signal_fk
        FOREIGN KEY (signal_id)
        REFERENCES signal (signal_id) ON DELETE CASCADE;

INSERT INTO signal_user_set (signal_id, user_set_id)
    SELECT signal_id, account_id + x'30000000'::int as user_set_id
      FROM signal_account;

CREATE INDEX ix_signal_user_set
    ON signal_user_set (signal_id);

CREATE UNIQUE INDEX ix_signal_user_set_user_set
    ON signal_user_set (user_set_id, signal_id);

DROP TABLE signal_account;

UPDATE "System"
   SET value = '100'
 WHERE field = 'socialtext-schema-version';

COMMIT;
