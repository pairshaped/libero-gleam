-- returns: SessionRow
INSERT INTO sessions (token, user_id)
VALUES (@token, @user_id)
RETURNING token, user_id
