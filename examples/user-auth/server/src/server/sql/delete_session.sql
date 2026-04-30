-- returns: DeletedSessionRow
DELETE FROM sessions
WHERE token = @token
RETURNING token
