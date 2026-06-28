-- Jeu de données de SEED synthétique (UC7) — AUCUNE donnée client réelle / PII.
-- En EF Core, ce seed est porté par HasData(...) et embarqué dans la migration. Ce fichier est
-- l'équivalent SQL pour la voie psql / MCP base de données (ou pour un reseed manuel).

INSERT INTO "Categories" ("Id", "Name") VALUES
    (1, 'Peripherals'),
    (2, 'Displays'),
    (3, 'Accessories');

INSERT INTO "Products" ("Id", "Sku", "Name", "Description", "Price", "AvailableStock", "CategoryId") VALUES
    (1, 'KB-MX-001', 'Mechanical Keyboard', 'Hot-swappable RGB keyboard', 119.99,  50, 1),
    (2, 'MS-WL-002', 'Wireless Mouse',      'Ergonomic 8k DPI mouse',      49.50, 120, 1),
    (3, 'MN-4K-003', '4K Monitor',          '27-inch IPS display',        329.00,  25, 2),
    (4, 'HB-UC-004', 'USB-C Hub',           '7-in-1 docking hub',          39.99, 200, 3);

-- Réaligner les séquences d'identité après des INSERT avec Id explicite.
SELECT setval(pg_get_serial_sequence('"Categories"', 'Id'), (SELECT MAX("Id") FROM "Categories"));
SELECT setval(pg_get_serial_sequence('"Products"',   'Id'), (SELECT MAX("Id") FROM "Products"));
