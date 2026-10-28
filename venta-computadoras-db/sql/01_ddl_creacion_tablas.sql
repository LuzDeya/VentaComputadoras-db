-- =====================================================================
-- Proyecto : Base de Datos - Venta de Computadoras
-- Motor    : SQL Server 2016 o superior (T-SQL)
-- Archivo  : 01_ddl_creacion_tablas.sql
-- Propósito: Crear la base de datos, tablas, llaves primarias, llaves
--            foráneas, restricciones (UNIQUE, CHECK, DEFAULT, NOT NULL),
--            índices y vistas.
-- ADVERTENCIA: elimina la base "tienda_computadoras" si ya existe.
-- =====================================================================

USE master;
GO

IF DB_ID(N'tienda_computadoras') IS NOT NULL
BEGIN
  ALTER DATABASE tienda_computadoras SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE tienda_computadoras;
END
GO

CREATE DATABASE tienda_computadoras COLLATE Modern_Spanish_CI_AS;
GO

USE tienda_computadoras;
GO

-- ---------------------------------------------------------------------
-- 1. CATEGORIAS
-- ---------------------------------------------------------------------
CREATE TABLE dbo.categorias (
  id_categoria  INT           IDENTITY(1,1) NOT NULL,
  nombre        VARCHAR(50)   NOT NULL,
  descripcion   VARCHAR(150)  NULL,
  CONSTRAINT pk_categorias        PRIMARY KEY (id_categoria),
  CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
);

-- ---------------------------------------------------------------------
-- 2. PROVEEDORES
-- ---------------------------------------------------------------------
CREATE TABLE dbo.proveedores (
  id_proveedor  INT           IDENTITY(1,1) NOT NULL,
  ruc           CHAR(11)      NOT NULL,
  razon_social  VARCHAR(120)  NOT NULL,
  contacto      VARCHAR(100)  NULL,
  telefono      VARCHAR(15)   NULL,
  email         VARCHAR(100)  NULL,
  direccion     VARCHAR(150)  NULL,
  activo        BIT           NOT NULL CONSTRAINT df_proveedores_activo DEFAULT 1,
  CONSTRAINT pk_proveedores       PRIMARY KEY (id_proveedor),
  CONSTRAINT uq_proveedores_ruc   UNIQUE (ruc),
  CONSTRAINT ck_proveedores_ruc   CHECK (ruc LIKE '[12]0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
  CONSTRAINT ck_proveedores_email CHECK (email IS NULL OR email LIKE '%_@_%._%')
);

-- ---------------------------------------------------------------------
-- 3. PRODUCTOS (computadoras, monitores, periféricos, componentes)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.productos (
  id_producto     INT            IDENTITY(1,1) NOT NULL,
  codigo          VARCHAR(20)    NOT NULL,
  nombre          VARCHAR(100)   NOT NULL,
  marca           VARCHAR(50)    NOT NULL,
  modelo          VARCHAR(50)    NULL,
  procesador      VARCHAR(60)    NULL,
  ram_gb          SMALLINT       NULL,
  almacenamiento  VARCHAR(40)    NULL,
  pantalla        VARCHAR(40)    NULL,
  gpu             VARCHAR(60)    NULL,
  descripcion     VARCHAR(255)   NULL,
  precio_compra   DECIMAL(10,2)  NOT NULL,
  precio_venta    DECIMAL(10,2)  NOT NULL,
  stock           INT            NOT NULL CONSTRAINT df_productos_stock    DEFAULT 0,
  stock_minimo    INT            NOT NULL CONSTRAINT df_productos_stockmin DEFAULT 0,
  garantia_meses  TINYINT        NOT NULL CONSTRAINT df_productos_garantia DEFAULT 12,
  activo          BIT            NOT NULL CONSTRAINT df_productos_activo   DEFAULT 1,
  id_categoria    INT            NOT NULL,
  id_proveedor    INT            NOT NULL,
  CONSTRAINT pk_productos          PRIMARY KEY (id_producto),
  CONSTRAINT uq_productos_codigo   UNIQUE (codigo),
  CONSTRAINT ck_productos_precios  CHECK (precio_compra >= 0 AND precio_venta >= precio_compra),
  CONSTRAINT ck_productos_stock    CHECK (stock >= 0 AND stock_minimo >= 0),
  CONSTRAINT ck_productos_ram      CHECK (ram_gb IS NULL OR ram_gb > 0),
  CONSTRAINT fk_productos_categoria FOREIGN KEY (id_categoria) REFERENCES dbo.categorias (id_categoria),
  CONSTRAINT fk_productos_proveedor FOREIGN KEY (id_proveedor) REFERENCES dbo.proveedores (id_proveedor)
);

CREATE INDEX ix_productos_categoria_precio ON dbo.productos (id_categoria, precio_venta);
CREATE INDEX ix_productos_marca            ON dbo.productos (marca);
CREATE INDEX ix_productos_proveedor        ON dbo.productos (id_proveedor);

-- ---------------------------------------------------------------------
-- 4. CLIENTES
-- ---------------------------------------------------------------------
CREATE TABLE dbo.clientes (
  id_cliente        INT           IDENTITY(1,1) NOT NULL,
  tipo_documento    VARCHAR(3)    NOT NULL,
  numero_documento  VARCHAR(12)   NOT NULL,
  nombre            VARCHAR(120)  NOT NULL,
  direccion         VARCHAR(150)  NULL,
  telefono          VARCHAR(15)   NULL,
  email             VARCHAR(100)  NULL,
  fecha_registro    DATETIME      NOT NULL CONSTRAINT df_clientes_fecha DEFAULT GETDATE(),
  CONSTRAINT pk_clientes           PRIMARY KEY (id_cliente),
  CONSTRAINT uq_clientes_documento UNIQUE (tipo_documento, numero_documento),
  CONSTRAINT ck_clientes_tipo      CHECK (tipo_documento IN ('DNI', 'RUC', 'CE')),
  CONSTRAINT ck_clientes_documento CHECK (
        numero_documento NOT LIKE '%[^0-9]%'
    AND (   (tipo_documento = 'DNI' AND LEN(numero_documento) = 8)
         OR (tipo_documento = 'RUC' AND LEN(numero_documento) = 11 AND numero_documento LIKE '[12]0%')
         OR (tipo_documento = 'CE'  AND LEN(numero_documento) BETWEEN 9 AND 12))
  ),
  CONSTRAINT ck_clientes_email CHECK (email IS NULL OR email LIKE '%_@_%._%')
);

-- ---------------------------------------------------------------------
-- 5. EMPLEADOS
-- ---------------------------------------------------------------------
CREATE TABLE dbo.empleados (
  id_empleado  INT           IDENTITY(1,1) NOT NULL,
  dni          CHAR(8)       NOT NULL,
  nombres      VARCHAR(100)  NOT NULL,
  cargo        VARCHAR(15)   NOT NULL,
  email        VARCHAR(100)  NULL,
  activo       BIT           NOT NULL CONSTRAINT df_empleados_activo DEFAULT 1,
  CONSTRAINT pk_empleados       PRIMARY KEY (id_empleado),
  CONSTRAINT uq_empleados_dni   UNIQUE (dni),
  CONSTRAINT ck_empleados_dni   CHECK (dni LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
  CONSTRAINT ck_empleados_cargo CHECK (cargo IN ('VENDEDOR', 'CAJERO', 'ADMINISTRADOR'))
);

-- ---------------------------------------------------------------------
-- 6. SERIES_COMPROBANTE (correlativo de boletas y facturas)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.series_comprobante (
  serie             CHAR(4)     NOT NULL,
  tipo_comprobante  VARCHAR(7)  NOT NULL,
  ultimo_numero     INT         NOT NULL CONSTRAINT df_series_numero DEFAULT 0,
  CONSTRAINT pk_series_comprobante PRIMARY KEY (serie),
  CONSTRAINT ck_series_formato CHECK (
       (tipo_comprobante = 'BOLETA'  AND serie LIKE 'B[0-9][0-9][0-9]')
    OR (tipo_comprobante = 'FACTURA' AND serie LIKE 'F[0-9][0-9][0-9]')
  ),
  CONSTRAINT ck_series_numero CHECK (ultimo_numero >= 0)
);

-- ---------------------------------------------------------------------
-- 7. VENTAS (cabecera del comprobante)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.ventas (
  id_venta          INT            IDENTITY(1,1) NOT NULL,
  tipo_comprobante  VARCHAR(7)     NOT NULL,
  serie             CHAR(4)        NOT NULL,
  numero            INT            NOT NULL,
  fecha             DATETIME       NOT NULL CONSTRAINT df_ventas_fecha  DEFAULT GETDATE(),
  id_cliente        INT            NOT NULL,
  id_empleado       INT            NOT NULL,
  op_gravada        DECIMAL(12,2)  NOT NULL CONSTRAINT df_ventas_op     DEFAULT 0,
  igv               DECIMAL(12,2)  NOT NULL CONSTRAINT df_ventas_igv    DEFAULT 0,
  total             DECIMAL(12,2)  NOT NULL CONSTRAINT df_ventas_total  DEFAULT 0,
  metodo_pago       VARCHAR(15)    NOT NULL,
  estado            VARCHAR(7)     NOT NULL CONSTRAINT df_ventas_estado DEFAULT 'PAGADA',
  motivo_anulacion  VARCHAR(200)   NULL,
  CONSTRAINT pk_ventas             PRIMARY KEY (id_venta),
  CONSTRAINT uq_ventas_comprobante UNIQUE (serie, numero),
  CONSTRAINT ck_ventas_tipo        CHECK (tipo_comprobante IN ('BOLETA', 'FACTURA')),
  CONSTRAINT ck_ventas_numero      CHECK (numero > 0),
  CONSTRAINT ck_ventas_montos      CHECK (op_gravada >= 0 AND igv >= 0 AND total = op_gravada + igv),
  CONSTRAINT ck_ventas_metodo      CHECK (metodo_pago IN ('EFECTIVO', 'TARJETA', 'YAPE', 'PLIN', 'TRANSFERENCIA')),
  CONSTRAINT ck_ventas_estado      CHECK (estado IN ('PAGADA', 'ANULADA')),
  CONSTRAINT fk_ventas_serie    FOREIGN KEY (serie)       REFERENCES dbo.series_comprobante (serie),
  CONSTRAINT fk_ventas_cliente  FOREIGN KEY (id_cliente)  REFERENCES dbo.clientes (id_cliente),
  CONSTRAINT fk_ventas_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleados (id_empleado)
);

CREATE INDEX ix_ventas_fecha          ON dbo.ventas (fecha);
CREATE INDEX ix_ventas_cliente_fecha  ON dbo.ventas (id_cliente, fecha);
CREATE INDEX ix_ventas_empleado_fecha ON dbo.ventas (id_empleado, fecha);

-- ---------------------------------------------------------------------
-- 8. DETALLE_VENTA (líneas del comprobante)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.detalle_venta (
  id_venta         INT            NOT NULL,
  item             SMALLINT       NOT NULL,
  id_producto      INT            NOT NULL,
  cantidad         INT            NOT NULL,
  precio_unitario  DECIMAL(10,2)  NOT NULL,
  importe          DECIMAL(12,2)  NOT NULL,
  CONSTRAINT pk_detalle_venta    PRIMARY KEY (id_venta, item),
  CONSTRAINT ck_detalle_item     CHECK (item > 0),
  CONSTRAINT ck_detalle_cantidad CHECK (cantidad > 0),
  CONSTRAINT ck_detalle_precio   CHECK (precio_unitario >= 0),
  CONSTRAINT ck_detalle_importe  CHECK (importe = cantidad * precio_unitario),
  CONSTRAINT fk_detalle_venta FOREIGN KEY (id_venta)
    REFERENCES dbo.ventas (id_venta) ON DELETE CASCADE,
  CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto)
    REFERENCES dbo.productos (id_producto)
);

CREATE INDEX ix_detalle_producto ON dbo.detalle_venta (id_producto);
GO

-- ---------------------------------------------------------------------
-- 9. VISTAS DE APOYO
-- ---------------------------------------------------------------------
-- Comprobante legible: serie-número, cliente, vendedor y montos
CREATE VIEW dbo.vw_comprobantes AS
SELECT v.id_venta,
       v.serie + '-' + RIGHT('00000000' + CAST(v.numero AS VARCHAR(8)), 8) AS comprobante,
       v.tipo_comprobante,
       v.fecha,
       c.tipo_documento,
       c.numero_documento,
       c.nombre   AS cliente,
       e.nombres  AS vendedor,
       v.op_gravada,
       v.igv,
       v.total,
       v.metodo_pago,
       v.estado
FROM dbo.ventas v
JOIN dbo.clientes  c ON c.id_cliente  = v.id_cliente
JOIN dbo.empleados e ON e.id_empleado = v.id_empleado;
GO

-- Productos que llegaron al stock mínimo (para reponer)
CREATE VIEW dbo.vw_stock_bajo AS
SELECT p.id_producto, p.codigo, p.nombre, p.marca, p.stock, p.stock_minimo,
       pr.razon_social AS proveedor, pr.telefono AS telefono_proveedor
FROM dbo.productos p
JOIN dbo.proveedores pr ON pr.id_proveedor = p.id_proveedor
WHERE p.activo = 1
  AND p.stock <= p.stock_minimo;
GO

PRINT 'Base de datos tienda_computadoras creada correctamente.';
