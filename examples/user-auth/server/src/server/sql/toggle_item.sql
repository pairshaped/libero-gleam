-- returns: ItemRow
UPDATE items
SET completed = NOT completed
WHERE id = @id AND user_id = @user_id
RETURNING id, title, completed
