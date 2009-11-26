BEGIN;

-- Introduce the notion of user sets for permissioning.

-- Include the "from" set with role in the "into" set.
-- Contains the "real" roles in our system
CREATE TABLE user_set_include (
    from_set_id integer NOT NULL,
    into_set_id integer NOT NULL,
    role_id integer NOT NULL,
    CONSTRAINT no_self_includes CHECK (from_set_id <> into_set_id)
);
ALTER TABLE ONLY user_set_include
    ADD CONSTRAINT user_set_include_role
            FOREIGN KEY (role_id)
            REFERENCES "Role"(role_id) ON DELETE RESTRICT;
ALTER TABLE ONLY user_set_include
    ADD CONSTRAINT "user_set_include_pkey"
    PRIMARY KEY (from_set_id, into_set_id);
CREATE UNIQUE INDEX idx_user_set_include_rev
    ON user_set_include (into_set_id,from_set_id);
CREATE UNIQUE INDEX idx_user_set_include_pkey_and_role
    ON user_set_include (from_set_id,into_set_id,role_id);
CREATE UNIQUE INDEX idx_user_set_include_rev_and_role
    ON user_set_include (into_set_id,from_set_id,role_id);

-- This is the "maintenance" table for the transitive closure on the
-- user_set_include table above.
CREATE TABLE user_set_path (
    from_set_id integer NOT NULL, -- Start
    via_set_id integer NOT NULL, -- the "last hop"
    into_set_id integer NOT NULL, -- End
    role_id integer NOT NULL, -- the role on that "last hop" in the destination set
    vlist integer[] NOT NULL
);
ALTER TABLE ONLY user_set_path
    ADD CONSTRAINT user_set_path_role
            FOREIGN KEY (role_id)
            REFERENCES "Role"(role_id) ON DELETE RESTRICT;
CREATE INDEX idx_user_set_path_wholepath
    ON user_set_path (from_set_id,into_set_id);
CREATE INDEX idx_user_set_path_via
    ON user_set_path (via_set_id,into_set_id);
CREATE INDEX idx_user_set_path_wholepath_rev
    ON user_set_path (into_set_id,from_set_id);
CREATE INDEX idx_user_set_path_wholepath_and_role
    ON user_set_path (from_set_id,into_set_id,role_id);
CREATE INDEX idx_user_set_path_rev_and_role
    ON user_set_path (into_set_id,from_set_id,role_id);

-- Special index type to allow searching within an int[].  Requires the
-- "intarray" postgres extension for 8.1
CREATE INDEX idx_user_set_path_vlist
    ON user_set_path USING gist (vlist gist__int_ops);

-- The transitive closure on user_set_include
CREATE VIEW user_set_include_tc AS
  SELECT DISTINCT from_set_id, via_set_id, into_set_id, role_id
  FROM user_set_path;

-- Now add a user_set_id to "container" objects
-- 0x20000001 = 536870913

CREATE SEQUENCE "user_set_id_seq"
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    START WITH 536870913
    CACHE 1; -- will be inserting a bunch per txn

ALTER TABLE "Workspace" ADD COLUMN user_set_id integer NOT NULL DEFAULT nextval('user_set_id_seq');
ALTER TABLE "Account" ADD COLUMN user_set_id integer NOT NULL DEFAULT nextval('user_set_id_seq');
ALTER TABLE groups ADD COLUMN user_set_id integer NOT NULL DEFAULT nextval('user_set_id_seq');

CREATE TABLE user_set_plugin (
    user_set_id integer NOT NULL,
    plugin text NOT NULL
);
ALTER TABLE ONLY user_set_plugin
    ADD CONSTRAINT "user_set_plugin_pkey"
    PRIMARY KEY (user_set_id, plugin);
CREATE UNIQUE INDEX user_set_plugin_ukey ON user_set_plugin (plugin, user_set_id);

CREATE TABLE user_set_plugin_pref (
    user_set_id integer NOT NULL,
    plugin text NOT NULL,
    "key" text NOT NULL,
    value text NOT NULL
);
ALTER TABLE ONLY user_set_plugin_pref
    ADD CONSTRAINT user_set_plugin_pref_fk
            FOREIGN KEY (user_set_id, plugin)
            REFERENCES user_set_plugin(user_set_id,plugin) ON DELETE CASCADE;
CREATE INDEX idx_user_set_plugin_pref ON user_set_plugin_pref (user_set_id, plugin);
CREATE INDEX idx_user_set_plugin_pref_key ON user_set_plugin_pref (user_set_id, plugin,"key");

INSERT INTO user_set_plugin
SELECT user_set_id, plugin
FROM "Account"
NATURAL JOIN account_plugin;

INSERT INTO user_set_plugin
SELECT user_set_id, plugin
FROM "Workspace"
NATURAL JOIN workspace_plugin;

INSERT INTO user_set_plugin_pref
SELECT user_set_id, plugin, key, value
FROM "Workspace"
JOIN workspace_plugin_pref USING (workspace_id);

DROP TABLE account_plugin;
DROP TABLE workspace_plugin_pref;
DROP TABLE workspace_plugin;

UPDATE "System"
   SET value = '95'
 WHERE field = 'socialtext-schema-version';

COMMIT;
