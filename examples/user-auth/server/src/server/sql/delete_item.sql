-- returns: DeletedRow
DELETE FROM items
WHERE id = @id AND user_id = @user_id
RETURNING id
