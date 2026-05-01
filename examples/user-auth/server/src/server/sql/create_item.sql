-- returns: ItemRow
INSERT INTO items (user_id, title, completed)
VALUES (@user_id, @title, 0)
RETURNING id, title, completed
