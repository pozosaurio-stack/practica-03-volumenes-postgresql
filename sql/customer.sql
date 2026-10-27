CREATE TABLE customer (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fullname VARCHAR(120) NOT NULL,
    status BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO customer (fullname, status)
VALUES
    ('Ana Torres', TRUE),
    ('Luis Mendoza', FALSE);

SELECT id, fullname, status
FROM customer
ORDER BY id;

