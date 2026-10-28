-- =====================================================================
-- Proyecto : Base de Datos - Venta de Computadoras
-- Motor    : SQL Server 2016 o superior (T-SQL)
-- Archivo  : 02_dml_datos_prueba.sql
-- Propósito: Insertar los datos de prueba iniciales.
-- Requisito: haber ejecutado antes 01_ddl_creacion_tablas.sql
-- Nota     : datos ficticios. Los precios de venta incluyen IGV (18 %).
-- =====================================================================

USE tienda_computadoras;
GO

-- ------------------------------ CATEGORÍAS ------------------------------
SET IDENTITY_INSERT dbo.categorias ON;
INSERT INTO dbo.categorias (id_categoria, nombre, descripcion) VALUES
  (1, 'Laptops',          'Computadoras portátiles'),
  (2, 'PC de escritorio', 'Equipos de escritorio armados'),
  (3, 'Monitores',        'Pantallas y monitores'),
  (4, 'Periféricos',      'Teclados, mouse y audífonos'),
  (5, 'Componentes',      'Almacenamiento, memorias y tarjetas');
SET IDENTITY_INSERT dbo.categorias OFF;

-- ------------------------------ PROVEEDORES -----------------------------
SET IDENTITY_INSERT dbo.proveedores ON;
INSERT INTO dbo.proveedores (id_proveedor, ruc, razon_social, contacto, telefono, email, direccion, activo) VALUES
  (1, '20511111111', 'TecnoAndina Distribuciones S.A.C.', 'Carlos Ríos',   '014445566', 'ventas@tecnoandina.pe',  'Av. Wilson 1250, Lima',    1),
  (2, '20522222222', 'Importaciones Digital Perú S.A.',   'Rosa Medina',   '014778899', 'pedidos@digitalperu.pe', 'Jr. Paruro 980, Lima',     1),
  (3, '20533333333', 'Gamer Zone Mayoristas E.I.R.L.',    'Jorge Paredes', '064212121', 'contacto@gamerzone.pe',  'Calle Real 455, Huancayo', 1);
SET IDENTITY_INSERT dbo.proveedores OFF;

-- ------------------------------- PRODUCTOS ------------------------------
SET IDENTITY_INSERT dbo.productos ON;
INSERT INTO dbo.productos
  (id_producto, codigo, nombre, marca, modelo, procesador, ram_gb, almacenamiento, pantalla, gpu, descripcion,
   precio_compra, precio_venta, stock, stock_minimo, garantia_meses, activo, id_categoria, id_proveedor) VALUES
  (1, 'LAP-LEN-IPS3',   'Laptop IdeaPad Slim 3',   'Lenovo',     '15ABR8',         'AMD Ryzen 5 7530U',    16,   '512 GB SSD',    '15.6" FHD',       'Radeon integrada',       'Windows 11 Home',
   1850.00, 2299.00, 12,  3, 12, 1, 1, 1),
  (2, 'LAP-HP-VIC15',   'Laptop Victus 15',        'HP',         '15-fa1xxx',      'Intel Core i5-12450H', 16,   '512 GB SSD',    '15.6" FHD 144Hz', 'NVIDIA RTX 3050 6GB',    'Windows 11 Home',
   3200.00, 3899.00,  6,  2, 12, 1, 1, 2),
  (3, 'LAP-ASU-VB15',   'Laptop Vivobook 15',      'ASUS',       'X1504ZA',        'Intel Core i3-1215U',   8,   '512 GB SSD',    '15.6" FHD',       'Intel UHD',              'Windows 11 Home',
   1350.00, 1699.00, 10,  3, 12, 1, 1, 1),
  (4, 'PC-GMR-R5',      'PC Gamer Ryzen 5',        'Ensamblada', 'GZ-R5-6600',     'AMD Ryzen 5 5600',     16,   '1 TB SSD NVMe', NULL,              'AMD Radeon RX 6600 8GB', 'Fuente 600W 80+ Bronze',
   2850.00, 3499.00,  5,  2, 12, 1, 2, 3),
  (5, 'MON-LG-24',      'Monitor 24" Full HD IPS', 'LG',         '24MR400',        NULL,                 NULL,   NULL,            '24" 1920x1080',   NULL,                     'Panel IPS 100Hz, HDMI y VGA',
    420.00,  549.00, 20,  5, 12, 1, 3, 2),
  (6, 'TEC-RED-K552',   'Teclado mecánico Kumara', 'Redragon',   'K552',           NULL,                 NULL,   NULL,            NULL,              NULL,                     'Switch Red, USB, español',
    110.00,  159.00, 30,  8,  6, 1, 4, 3),
  (7, 'MOU-LOG-G203',   'Mouse gamer G203',        'Logitech',   'G203 Lightsync', NULL,                 NULL,   NULL,            NULL,              NULL,                     '8000 DPI, 6 botones',
     60.00,   89.90, 40, 10,  6, 1, 4, 3),
  (8, 'SSD-KIN-NV2-1T', 'SSD NV2 1TB NVMe',        'Kingston',   'SNV2S/1000G',    NULL,                 NULL,   '1 TB',          NULL,              NULL,                     'PCIe 4.0 NVMe M.2, 3500 MB/s',
    180.00,  249.00, 25,  5, 36, 1, 5, 1);
SET IDENTITY_INSERT dbo.productos OFF;

-- -------------------------------- CLIENTES ------------------------------
SET IDENTITY_INSERT dbo.clientes ON;
INSERT INTO dbo.clientes (id_cliente, tipo_documento, numero_documento, nombre, direccion, telefono, email, fecha_registro) VALUES
  (1, 'DNI', '71234567',    'Juan Carlos Pérez Quispe',               'Jr. Puno 345, Huancayo',         '964111222', 'juan.perez@gmail.com',          '2026-09-15T10:00:00'),
  (2, 'DNI', '72345678',    'María Elena Rojas Huamán',               'Av. Huancavelica 820, El Tambo', '965333444', 'maria.rojas@hotmail.com',       '2026-09-20T16:30:00'),
  (3, 'RUC', '20601234567', 'Inversiones Andinas S.A.C.',             'Av. Ferrocarril 1020, Huancayo', '064223344', 'compras@inversionesandinas.pe', '2026-10-01T09:15:00'),
  (4, 'RUC', '20487654321', 'Instituto Educativo Los Andes E.I.R.L.', 'Jr. Arequipa 560, Chilca',       '064255667', 'logistica@iela.edu.pe',         '2026-10-12T11:45:00');
SET IDENTITY_INSERT dbo.clientes OFF;

-- ------------------------------- EMPLEADOS ------------------------------
SET IDENTITY_INSERT dbo.empleados ON;
INSERT INTO dbo.empleados (id_empleado, dni, nombres, cargo, email, activo) VALUES
  (1, '45678912', 'Luis Torres Vargas',   'VENDEDOR',      'ltorres@tienda.pe',   1),
  (2, '46789123', 'Ana Castillo Mendoza', 'VENDEDOR',      'acastillo@tienda.pe', 1),
  (3, '47891234', 'Pedro Salazar Rivera', 'ADMINISTRADOR', 'psalazar@tienda.pe',  1);
SET IDENTITY_INSERT dbo.empleados OFF;

-- -------------------------- SERIES DE COMPROBANTE -----------------------
INSERT INTO dbo.series_comprobante (serie, tipo_comprobante, ultimo_numero) VALUES
  ('B001', 'BOLETA',  2),
  ('F001', 'FACTURA', 2);

-- -------------------------------- VENTAS --------------------------------
-- total = suma de importes; op_gravada = total / 1.18; igv = total - op_gravada
SET IDENTITY_INSERT dbo.ventas ON;
INSERT INTO dbo.ventas
  (id_venta, tipo_comprobante, serie, numero, fecha, id_cliente, id_empleado, op_gravada, igv, total, metodo_pago, estado) VALUES
  (1, 'BOLETA',  'B001', 1, '2026-10-05T11:20:00', 1, 1, 2024.49,  364.41, 2388.90, 'EFECTIVO',      'PAGADA'),
  (2, 'FACTURA', 'F001', 1, '2026-10-10T15:05:00', 3, 2, 5715.25, 1028.75, 6744.00, 'TRANSFERENCIA', 'PAGADA'),
  (3, 'BOLETA',  'B001', 2, '2026-10-18T17:40:00', 2, 1, 3565.25,  641.75, 4207.00, 'TARJETA',       'PAGADA'),
  (4, 'FACTURA', 'F001', 2, '2026-10-25T10:10:00', 4, 2, 1436.02,  258.48, 1694.50, 'TRANSFERENCIA', 'PAGADA');
SET IDENTITY_INSERT dbo.ventas OFF;

-- ---------------------------- DETALLE DE VENTA --------------------------
INSERT INTO dbo.detalle_venta (id_venta, item, id_producto, cantidad, precio_unitario, importe) VALUES
  (1, 1, 1, 1, 2299.00, 2299.00),
  (1, 2, 7, 1,   89.90,   89.90),
  (2, 1, 3, 3, 1699.00, 5097.00),
  (2, 2, 5, 3,  549.00, 1647.00),
  (3, 1, 4, 1, 3499.00, 3499.00),
  (3, 2, 6, 1,  159.00,  159.00),
  (3, 3, 5, 1,  549.00,  549.00),
  (4, 1, 8, 5,  249.00, 1245.00),
  (4, 2, 7, 5,   89.90,  449.50);
GO

-- Verificación rápida
SELECT 'categorias' AS tabla, COUNT(*) AS registros FROM dbo.categorias
UNION ALL SELECT 'proveedores',        COUNT(*) FROM dbo.proveedores
UNION ALL SELECT 'productos',          COUNT(*) FROM dbo.productos
UNION ALL SELECT 'clientes',           COUNT(*) FROM dbo.clientes
UNION ALL SELECT 'empleados',          COUNT(*) FROM dbo.empleados
UNION ALL SELECT 'series_comprobante', COUNT(*) FROM dbo.series_comprobante
UNION ALL SELECT 'ventas',             COUNT(*) FROM dbo.ventas
UNION ALL SELECT 'detalle_venta',      COUNT(*) FROM dbo.detalle_venta;
GO
