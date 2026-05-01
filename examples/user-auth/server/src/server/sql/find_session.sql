-- returns: SessionRow
SELECT token, user_id
FROM sessions
WHERE token = @token
