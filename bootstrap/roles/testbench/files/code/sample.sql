-- comment; TODO: keywords, functions, strings
SELECT u.id, COUNT(*) AS n
FROM users AS u
JOIN orders o ON o.user_id = u.id
WHERE u.name = 'root' AND u.active = TRUE
GROUP BY u.id
HAVING COUNT(*) > 10
ORDER BY n DESC;
