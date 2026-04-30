-- returns: ItemRow
SELECT id, title, completed
FROM items
WHERE user_id = @user_id
ORDER BY id
