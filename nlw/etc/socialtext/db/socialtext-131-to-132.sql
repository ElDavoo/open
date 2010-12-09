BEGIN;

CREATE OR REPLACE FUNCTION signal_hide() RETURNS trigger AS $signal_hide$
BEGIN
  IF NEW.hidden = TRUE and OLD.hidden = FALSE THEN
    DELETE FROM signal_asset WHERE signal_asset.signal_id = NEW.signal_id;
    UPDATE event
       SET hidden = TRUE
     WHERE event.signal_id = NEW.signal_id;
  END IF;
  RETURN NEW;
END;
$signal_hide$ LANGUAGE plpgsql;

CREATE TRIGGER signal_hide AFTER UPDATE ON signal FOR EACH ROW EXECUTE PROCEDURE signal_hide();


UPDATE "System"
   SET value = '132'
 WHERE field = 'socialtext-schema-version';

COMMIT;
