-- =====================================================================
-- Proyecto : Base de Datos - Venta de Computadoras
-- Motor    : SQL Server (T-SQL)
-- Archivo  : 04_pruebas.sql
-- Propósito: Probar los procedimientos almacenados y las consultas clave.
-- Requisito: haber ejecutado 01, 02 y 03.
-- Uso      : ejecutar todo el archivo de una vez (F5 en SSMS o
--            Ctrl + Shift + E en VS Code). Cada resultado sale en su
--            propia tabla, en orden.
-- =====================================================================

USE tienda_computadoras;
GO

DECLARE @id_boleta INT, @id_factura INT;

-- 1) Catálogo: laptops (categoría 1) de hasta S/ 3000
EXEC dbo.sp_listar_productos @id_categoria = 1, @precio_max = 3000.00;

-- 2) Registrar una venta a cliente con DNI → BOLETA B001-00000003
--    Laptop HP Victus 15 + Mouse Logitech G203 → total S/ 3988.90
EXEC dbo.sp_registrar_venta
     @id_cliente  = 2,
     @id_empleado = 1,
     @metodo_pago = 'YAPE',
     @items       = N'[{"id_producto": 2, "cantidad": 1}, {"id_producto": 7, "cantidad": 1}]',
     @id_venta    = @id_boleta OUTPUT;

-- 3) Ver el comprobante generado (cabecera + detalle)
EXEC dbo.sp_ver_comprobante @id_venta = @id_boleta;

-- 4) El stock bajó: HP Victus 6 → 5, Mouse G203 40 → 39
SELECT id_producto, nombre, stock FROM dbo.productos WHERE id_producto IN (2, 7);

-- 5) Registrar una venta a empresa con RUC → FACTURA F001-00000003
EXEC dbo.sp_registrar_venta
     @id_cliente  = 3,
     @id_empleado = 2,
     @metodo_pago = 'TRANSFERENCIA',
     @items       = N'[{"id_producto": 1, "cantidad": 2}, {"id_producto": 5, "cantidad": 2}]',
     @id_venta    = @id_factura OUTPUT;

-- 6) Anular la boleta del paso 2 (el stock vuelve: HP Victus 5 → 6, Mouse 39 → 40)
EXEC dbo.sp_anular_venta @id_venta = @id_boleta, @motivo = 'Cliente desistió de la compra';
SELECT id_producto, nombre, stock FROM dbo.productos WHERE id_producto IN (2, 7);

-- 7) Ingreso de mercadería: +3 PC Gamer
EXEC dbo.sp_ingresar_stock @id_producto = 4, @cantidad = 3;

-- 8) Consultas y reportes
EXEC dbo.sp_historial_cliente @id_cliente = 3;
EXEC dbo.sp_ventas_por_rango @desde = '2026-10-01', @hasta = '2026-12-31';
EXEC dbo.sp_reporte_ventas_por_mes;
EXEC dbo.sp_reporte_productos_mas_vendidos @limite = 5;
EXEC dbo.sp_reporte_ventas_por_vendedor;
SELECT * FROM dbo.vw_stock_bajo;
SELECT * FROM dbo.vw_comprobantes ORDER BY fecha;
GO

-- =====================================================================
-- 9) PRUEBAS DE ERROR: deben mostrar un mensaje en rojo y NO guardar nada.
--    Selecciona UNA línea y ejecútala sola.
-- =====================================================================
/*
DECLARE @x INT; EXEC dbo.sp_registrar_venta 1, 1, 'EFECTIVO', N'[{"id_producto": 4, "cantidad": 99}]', @x OUTPUT;  -- Stock insuficiente
DECLARE @x INT; EXEC dbo.sp_registrar_venta 99, 1, 'EFECTIVO', N'[{"id_producto": 1, "cantidad": 1}]', @x OUTPUT; -- Cliente no existe
DECLARE @x INT; EXEC dbo.sp_registrar_venta 1, 1, 'EFECTIVO', N'[]', @x OUTPUT;                                    -- Sin productos
EXEC dbo.sp_anular_venta 1, 'prueba';                                                                               -- (ejecútala 2 veces) Ya está anulada
INSERT INTO dbo.productos (codigo, nombre, marca, precio_compra, precio_venta, stock, id_categoria, id_proveedor) VALUES ('X-01', 'Prueba', 'X', 100, 50, 1, 1, 1);  -- CHECK precio
INSERT INTO dbo.clientes (tipo_documento, numero_documento, nombre) VALUES ('DNI', '123', 'Prueba');               -- CHECK DNI inválido
INSERT INTO dbo.clientes (tipo_documento, numero_documento, nombre) VALUES ('DNI', '71234567', 'Duplicado');       -- UNIQUE documento
DELETE FROM dbo.categorias WHERE id_categoria = 1;                                                                  -- FK: tiene productos
*/
