-- =====================================================================
-- Proyecto : Base de Datos - Venta de Computadoras
-- Motor    : SQL Server 2016 SP1 o superior (T-SQL)
-- Archivo  : 03_procedimientos_almacenados.sql
-- Propósito: Procedimientos almacenados para las transacciones del
--            proceso de venta y consultas clave del sistema.
-- Requisito: haber ejecutado 01 y 02.
-- =====================================================================

USE tienda_computadoras;
GO

-- =====================================================================
-- SP 1: sp_registrar_venta  →  POST /api/ventas
--  Registra la venta completa en UNA transacción:
--   1. Valida cliente, empleado y lista de productos.
--   2. Asigna serie (BOLETA B001 si DNI/CE, FACTURA F001 si RUC) y número.
--   3. Valida y descuenta el stock de cada producto.
--   4. Inserta la cabecera y el detalle con el precio vigente.
--   5. Calcula op. gravada, IGV (18 %) y total.
--  Si algo falla, hace ROLLBACK y no se guarda nada.
--
--  @items es un JSON: N'[{"id_producto":2,"cantidad":1}, ...]'
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_registrar_venta
  @id_cliente   INT,
  @id_empleado  INT,
  @metodo_pago  VARCHAR(15),
  @items        NVARCHAR(MAX),
  @id_venta     INT OUTPUT
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @tipo_doc   VARCHAR(3),
          @tipo_comp  VARCHAR(7),
          @serie      CHAR(4),
          @numero     INT,
          @total      DECIMAL(12,2),
          @op_gravada DECIMAL(12,2),
          @mensaje    NVARCHAR(200);

  DECLARE @detalle TABLE (
    item         SMALLINT NOT NULL,
    id_producto  INT      NULL,
    cantidad     INT      NULL
  );

  -- ---------- Validaciones previas ----------
  SELECT @tipo_doc = tipo_documento FROM dbo.clientes WHERE id_cliente = @id_cliente;
  IF @tipo_doc IS NULL
    THROW 50001, N'El cliente no existe', 1;

  IF NOT EXISTS (SELECT 1 FROM dbo.empleados WHERE id_empleado = @id_empleado AND activo = 1)
    THROW 50002, N'El empleado no existe o está inactivo', 1;

  IF @items IS NULL OR ISJSON(@items) = 0
    THROW 50003, N'La lista de productos no tiene un formato JSON válido', 1;

  INSERT INTO @detalle (item, id_producto, cantidad)
  SELECT CAST([key] AS SMALLINT) + 1,
         TRY_CAST(JSON_VALUE([value], '$.id_producto') AS INT),
         TRY_CAST(JSON_VALUE([value], '$.cantidad')    AS INT)
  FROM OPENJSON(@items);

  IF NOT EXISTS (SELECT 1 FROM @detalle)
    THROW 50004, N'La venta debe tener al menos un producto', 1;

  IF EXISTS (SELECT 1 FROM @detalle WHERE cantidad IS NULL OR cantidad <= 0)
    THROW 50005, N'Cantidad inválida en uno de los productos', 1;

  SELECT TOP 1 @mensaje = CONCAT(N'El producto ', ISNULL(CAST(d.id_producto AS VARCHAR(10)), 'NULL'),
                                 N' no existe o está inactivo')
  FROM @detalle d
  LEFT JOIN dbo.productos p ON p.id_producto = d.id_producto AND p.activo = 1
  WHERE p.id_producto IS NULL;

  IF @mensaje IS NOT NULL
    THROW 50006, @mensaje, 1;

  IF @tipo_doc = 'RUC'
  BEGIN
    SET @tipo_comp = 'FACTURA';
    SET @serie     = 'F001';
  END
  ELSE
  BEGIN
    SET @tipo_comp = 'BOLETA';
    SET @serie     = 'B001';
  END;

  -- ---------- Transacción ----------
  BEGIN TRY
    BEGIN TRANSACTION;

    -- Correlativo: incrementa y lee el número en una sola operación
    UPDATE dbo.series_comprobante
    SET @numero = ultimo_numero = ultimo_numero + 1
    WHERE serie = @serie;

    -- Valida stock (bloqueando las filas de los productos)
    SELECT TOP 1 @mensaje = CONCAT(N'Stock insuficiente para ', p.nombre,
                                   N' (disponible: ', p.stock, N')')
    FROM (SELECT id_producto, SUM(cantidad) AS cantidad
          FROM @detalle GROUP BY id_producto) r
    JOIN dbo.productos p WITH (UPDLOCK, HOLDLOCK) ON p.id_producto = r.id_producto
    WHERE p.stock < r.cantidad;

    IF @mensaje IS NOT NULL
      THROW 50007, @mensaje, 1;

    -- Descuenta stock
    UPDATE p
    SET p.stock = p.stock - r.cantidad
    FROM dbo.productos p
    JOIN (SELECT id_producto, SUM(cantidad) AS cantidad
          FROM @detalle GROUP BY id_producto) r ON r.id_producto = p.id_producto;

    -- Cabecera
    INSERT INTO dbo.ventas (tipo_comprobante, serie, numero, fecha, id_cliente, id_empleado, metodo_pago, estado)
    VALUES (@tipo_comp, @serie, @numero, GETDATE(), @id_cliente, @id_empleado, @metodo_pago, 'PAGADA');

    SET @id_venta = SCOPE_IDENTITY();

    -- Detalle con el precio vigente
    INSERT INTO dbo.detalle_venta (id_venta, item, id_producto, cantidad, precio_unitario, importe)
    SELECT @id_venta, d.item, d.id_producto, d.cantidad, p.precio_venta, d.cantidad * p.precio_venta
    FROM @detalle d
    JOIN dbo.productos p ON p.id_producto = d.id_producto;

    -- Totales (el precio de venta ya incluye IGV)
    SELECT @total = SUM(importe) FROM dbo.detalle_venta WHERE id_venta = @id_venta;
    SET @op_gravada = ROUND(@total / 1.18, 2);

    UPDATE dbo.ventas
    SET op_gravada = @op_gravada,
        igv        = @total - @op_gravada,
        total      = @total
    WHERE id_venta = @id_venta;

    COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SET @id_venta = NULL;
    THROW;
  END CATCH;

  SELECT * FROM dbo.vw_comprobantes WHERE id_venta = @id_venta;
END;
GO

-- =====================================================================
-- SP 2: sp_anular_venta  →  PATCH /api/ventas/:id/anular
--  Cambia el estado a ANULADA y devuelve el stock de cada producto.
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_anular_venta
  @id_venta  INT,
  @motivo    VARCHAR(200) = NULL
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @estado VARCHAR(7);

  BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @estado = estado
    FROM dbo.ventas WITH (UPDLOCK, HOLDLOCK)
    WHERE id_venta = @id_venta;

    IF @estado IS NULL
      THROW 50010, N'La venta no existe', 1;
    IF @estado = 'ANULADA'
      THROW 50011, N'La venta ya está anulada', 1;

    UPDATE p
    SET p.stock = p.stock + d.cantidad
    FROM dbo.productos p
    JOIN (SELECT id_producto, SUM(cantidad) AS cantidad
          FROM dbo.detalle_venta
          WHERE id_venta = @id_venta
          GROUP BY id_producto) d ON d.id_producto = p.id_producto;

    UPDATE dbo.ventas
    SET estado = 'ANULADA',
        motivo_anulacion = ISNULL(@motivo, 'Sin motivo')
    WHERE id_venta = @id_venta;

    COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
  END CATCH;

  SELECT * FROM dbo.vw_comprobantes WHERE id_venta = @id_venta;
END;
GO

-- =====================================================================
-- SP 3: sp_ingresar_stock  →  PATCH /api/productos/:id/stock
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_ingresar_stock
  @id_producto INT,
  @cantidad    INT
AS
BEGIN
  SET NOCOUNT ON;

  IF @cantidad IS NULL OR @cantidad <= 0
    THROW 50020, N'La cantidad debe ser mayor a cero', 1;

  UPDATE dbo.productos SET stock = stock + @cantidad WHERE id_producto = @id_producto;

  IF @@ROWCOUNT = 0
    THROW 50021, N'El producto no existe', 1;

  SELECT id_producto, codigo, nombre, stock FROM dbo.productos WHERE id_producto = @id_producto;
END;
GO

-- =====================================================================
-- SP 4: sp_listar_productos  →  GET /api/productos?categoria=&marca=&min=&max=
--  Los parámetros que no se envían (NULL) no filtran.
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_listar_productos
  @id_categoria INT           = NULL,
  @marca        VARCHAR(50)   = NULL,
  @precio_min   DECIMAL(10,2) = NULL,
  @precio_max   DECIMAL(10,2) = NULL
AS
BEGIN
  SET NOCOUNT ON;

  SELECT p.id_producto, p.codigo, p.nombre, p.marca, p.modelo,
         p.procesador, p.ram_gb, p.almacenamiento, p.pantalla, p.gpu,
         p.precio_venta, p.stock, c.nombre AS categoria
  FROM dbo.productos p
  JOIN dbo.categorias c ON c.id_categoria = p.id_categoria
  WHERE p.activo = 1
    AND (@id_categoria IS NULL OR p.id_categoria = @id_categoria)
    AND (@marca        IS NULL OR p.marca = @marca)
    AND (@precio_min   IS NULL OR p.precio_venta >= @precio_min)
    AND (@precio_max   IS NULL OR p.precio_venta <= @precio_max)
  ORDER BY p.precio_venta;
END;
GO

-- =====================================================================
-- SP 5: sp_ver_comprobante  →  GET /api/ventas/:id
--  Devuelve dos resultados: cabecera y detalle.
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_ver_comprobante
  @id_venta INT
AS
BEGIN
  SET NOCOUNT ON;

  SELECT * FROM dbo.vw_comprobantes WHERE id_venta = @id_venta;

  SELECT d.item, p.codigo, p.nombre + ' ' + p.marca AS descripcion,
         d.cantidad, d.precio_unitario, d.importe
  FROM dbo.detalle_venta d
  JOIN dbo.productos p ON p.id_producto = d.id_producto
  WHERE d.id_venta = @id_venta
  ORDER BY d.item;
END;
GO

-- =====================================================================
-- SP 6: sp_historial_cliente  →  GET /api/clientes/:id/ventas
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_historial_cliente
  @id_cliente INT
AS
BEGIN
  SET NOCOUNT ON;

  SELECT vc.id_venta, vc.comprobante, vc.fecha, vc.total, vc.metodo_pago, vc.estado
  FROM dbo.vw_comprobantes vc
  JOIN dbo.ventas v ON v.id_venta = vc.id_venta
  WHERE v.id_cliente = @id_cliente
  ORDER BY vc.fecha DESC;
END;
GO

-- =====================================================================
-- SP 7: sp_ventas_por_rango  →  GET /api/ventas?desde=&hasta=
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_ventas_por_rango
  @desde DATE,
  @hasta DATE
AS
BEGIN
  SET NOCOUNT ON;

  SELECT id_venta, comprobante, fecha, cliente, vendedor, total, metodo_pago, estado
  FROM dbo.vw_comprobantes
  WHERE fecha >= @desde
    AND fecha <  DATEADD(DAY, 1, @hasta)
  ORDER BY fecha;
END;
GO

-- =====================================================================
-- SP 8: sp_reporte_ventas_por_mes  →  GET /api/reportes/ventas-por-mes
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_reporte_ventas_por_mes
AS
BEGIN
  SET NOCOUNT ON;

  SELECT CONVERT(CHAR(7), fecha, 120) AS mes,
         COUNT(*)        AS cantidad_ventas,
         SUM(op_gravada) AS op_gravada,
         SUM(igv)        AS igv,
         SUM(total)      AS total_vendido
  FROM dbo.ventas
  WHERE estado = 'PAGADA'
  GROUP BY CONVERT(CHAR(7), fecha, 120)
  ORDER BY mes;
END;
GO

-- =====================================================================
-- SP 9: sp_reporte_productos_mas_vendidos  →  GET /api/reportes/productos-mas-vendidos?limite=
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_reporte_productos_mas_vendidos
  @limite INT = 5
AS
BEGIN
  SET NOCOUNT ON;

  SELECT TOP (@limite)
         p.id_producto, p.codigo, p.nombre, p.marca,
         SUM(d.cantidad) AS unidades_vendidas,
         SUM(d.importe)  AS ingresos
  FROM dbo.detalle_venta d
  JOIN dbo.ventas    v ON v.id_venta    = d.id_venta
  JOIN dbo.productos p ON p.id_producto = d.id_producto
  WHERE v.estado = 'PAGADA'
  GROUP BY p.id_producto, p.codigo, p.nombre, p.marca
  ORDER BY unidades_vendidas DESC, ingresos DESC;
END;
GO

-- =====================================================================
-- SP 10: sp_reporte_ventas_por_vendedor  →  GET /api/reportes/ventas-por-vendedor
-- =====================================================================
CREATE OR ALTER PROCEDURE dbo.sp_reporte_ventas_por_vendedor
AS
BEGIN
  SET NOCOUNT ON;

  SELECT e.id_empleado, e.nombres AS vendedor,
         COUNT(v.id_venta)       AS cantidad_ventas,
         ISNULL(SUM(v.total), 0) AS total_vendido
  FROM dbo.empleados e
  LEFT JOIN dbo.ventas v ON v.id_empleado = e.id_empleado AND v.estado = 'PAGADA'
  WHERE e.cargo = 'VENDEDOR'
  GROUP BY e.id_empleado, e.nombres
  ORDER BY total_vendido DESC;
END;
GO

PRINT 'Procedimientos almacenados creados correctamente.';
