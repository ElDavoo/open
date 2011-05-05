BEGIN;

CREATE OR REPLACE FUNCTION user_set_is_user(id bigint) RETURNS BOOLEAN as $$
BEGIN
    IF id <= x'10000000'::int THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END
$$
language plpgsql;

CREATE OR REPLACE FUNCTION user_set_is_group(id bigint) RETURNS BOOLEAN as $$
BEGIN
    IF id > x'10000000'::int AND id <= x'20000000'::int THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END
$$
language plpgsql;

CREATE OR REPLACE FUNCTION user_set_is_workspace(id bigint) RETURNS BOOLEAN as $$
BEGIN
    IF id > x'20000000'::int AND id <= x'30000000'::int THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END
$$
language plpgsql;

CREATE OR REPLACE FUNCTION user_set_is_account(id bigint) RETURNS BOOLEAN as $$
BEGIN
    IF id > x'30000000'::int THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END
$$
language plpgsql;

CREATE OR REPLACE FUNCTION shares_account(user1 bigint, user2 bigint) returns BOOLEAN AS $$
DECLARE
    myrec RECORD;
BEGIN
    SELECT into_set_id INTO myrec
    FROM
        user_set_path
    WHERE
        from_set_id = user1
    AND
        into_set_id > x'30000000'::int
    AND
        into_set_id in (
            SELECT DISTINCT into_set_id
            FROM user_set_path
            WHERE from_set_id = user2
              AND into_set_id > x'30000000'::int)
    LIMIT 1;
    RETURN FOUND;
END
$$
language plpgsql;

CREATE OR REPLACE FUNCTION user_removed_from_account() RETURNS "trigger" AS $$
DECLARE
    rel RECORD;
BEGIN
    IF user_set_is_user(OLD.from_set_id) AND user_set_is_account(OLD.into_set_id) THEN
        FOR rel IN
            SELECT 
                user_id, profile_field_id, other_user_id
            FROM
                profile_relationship 
            WHERE
                (user_id = OLD.from_set_id OR other_user_id = OLD.from_set_id) 
            AND
                profile_field_id IN (select profile_field_id FROM profile_field WHERE field_class = 'relationship')
        LOOP
            IF NOT shares_account(rel.user_id, rel.other_user_id) THEN
                DELETE FROM
                    PROFILE_RELATIONSHIP
                WHERE
                    user_id = rel.user_id
                AND
                    profile_field_id = rel.profile_field_id
                AND
                    other_user_id = rel.other_user_id;
            END IF;
        END LOOP;
    END IF;
    RETURN OLD;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER user_set_path_delete
    AFTER DELETE ON user_set_path
    FOR EACH ROW
    EXECUTE PROCEDURE user_removed_from_account();

UPDATE "System"
   SET value = '140'
 WHERE field = 'socialtext-schema-version';

COMMIT;

