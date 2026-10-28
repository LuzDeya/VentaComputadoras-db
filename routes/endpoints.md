# Rutas / Endpoints de la API

Mapeo de cada ruta REST con la consulta SQL o el procedimiento almacenado (SQL Server / T-SQL) que ejecuta en la base de datos `tienda_computadoras`.

- **URL base:** `http://localhost:3000/api`
- **Formato:** JSON
- **Códigos de respuesta:** `200` OK · `201` creado · `400` datos inválidos (CHECK) · `404` no encontrado · `409` conflicto (duplicado, sin stock o FK)

---

## 1. Productos

| Método | Ruta | Descripción | SQL / Procedimiento |
|--------|------|-------------|---------------------|
| GET | `/api/productos?categoria=&marca=&min=&max=` | Catálogo con filtros opcionales | `EXEC dbo.sp_listar_productos @id_categoria, @marca, @precio_min, @precio_max` |
| GET | `/api/productos/:id` | Ver un producto | `SELECT * FROM productos WHERE id_producto = ?` |
| POST | `/api/productos` | Registrar producto | `INSERT INTO productos (...) VALUES (...)` |
| PUT | `/api/productos/:id` | Actualizar datos o precio | `UPDATE productos SET ... WHERE id_producto = ?` |
| PATCH | `/api/productos/:id/stock` | Ingreso de mercadería | `EXEC dbo.sp_ingresar_stock @id_producto, @cantidad` |
| DELETE | `/api/productos/:id` | Baja lógica (no se borra porque tiene ventas) | `UPDATE dbo.productos SET activo = 0 WHERE id_producto = @id` |

**POST `/api/productos`**
```json
{
  "codigo": "LAP-ACE-AS5",
  "nombre": "Laptop Aspire 5",
  "marca": "Acer",
  "procesador": "Intel Core i5-1335U",
  "ram_gb": 16,
  "almacenamiento": "512 GB SSD",
  "precio_compra": 2100.00,
  "precio_venta": 2599.00,
  "stock": 8,
  "stock_minimo": 2,
  "id_categoria": 1,
  "id_proveedor": 1
}
```

**PATCH `/api/productos/4/stock`**
```json
{ "cantidad": 3 }
```

## 2. Categorías

| Método | Ruta | Descripción | SQL |
|--------|------|-------------|-----|
| GET | `/api/categorias` | Listar categorías | `SELECT * FROM categorias ORDER BY nombre` |
| POST | `/api/categorias` | Crear categoría | `INSERT INTO categorias (nombre, descripcion) VALUES (?, ?)` |
| GET | `/api/categorias/:id/productos` | Productos de una categoría | `EXEC dbo.sp_listar_productos @id_categoria = ?` |

## 3. Proveedores

| Método | Ruta | Descripción | SQL |
|--------|------|-------------|-----|
| GET | `/api/proveedores` | Listar proveedores activos | `SELECT * FROM proveedores WHERE activo = 1` |
| GET | `/api/proveedores/:id` | Ver proveedor | `SELECT * FROM proveedores WHERE id_proveedor = ?` |
| POST | `/api/proveedores` | Registrar proveedor | `INSERT INTO proveedores (...) VALUES (...)` |
| PUT | `/api/proveedores/:id` | Actualizar proveedor | `UPDATE proveedores SET ... WHERE id_proveedor = ?` |

## 4. Clientes

| Método | Ruta | Descripción | SQL / Procedimiento |
|--------|------|-------------|---------------------|
| GET | `/api/clientes` | Listar clientes | `SELECT * FROM clientes ORDER BY nombre` |
| GET | `/api/clientes/documento/:numero` | Buscar por DNI o RUC (en caja) | `SELECT * FROM clientes WHERE numero_documento = ?` |
| GET | `/api/clientes/:id` | Ver cliente | `SELECT * FROM clientes WHERE id_cliente = ?` |
| POST | `/api/clientes` | Registrar cliente (409 si el documento ya existe) | `INSERT INTO clientes (...) VALUES (...)` |
| PUT | `/api/clientes/:id` | Actualizar datos | `UPDATE clientes SET ... WHERE id_cliente = ?` |
| GET | `/api/clientes/:id/ventas` | Historial de compras | `EXEC dbo.sp_historial_cliente @id_cliente` |

**POST `/api/clientes`**
```json
{
  "tipo_documento": "DNI",
  "numero_documento": "73456789",
  "nombre": "Rosa Quispe Huamán",
  "telefono": "966555444",
  "email": "rosa.quispe@gmail.com"
}
```

## 5. Empleados

| Método | Ruta | Descripción | SQL |
|--------|------|-------------|-----|
| GET | `/api/empleados` | Listar empleados activos | `SELECT * FROM empleados WHERE activo = 1` |
| POST | `/api/empleados` | Registrar empleado | `INSERT INTO empleados (...) VALUES (...)` |

## 6. Ventas — proceso principal

| Método | Ruta | Descripción | SQL / Procedimiento |
|--------|------|-------------|---------------------|
| GET | `/api/ventas?desde=&hasta=` | Ventas por rango de fechas | `EXEC dbo.sp_ventas_por_rango @desde, @hasta` |
| GET | `/api/ventas/:id` | Ver comprobante (cabecera + detalle) | `EXEC dbo.sp_ver_comprobante @id_venta` |
| POST | `/api/ventas` | **Registrar venta** | `EXEC dbo.sp_registrar_venta @id_cliente, @id_empleado, @metodo_pago, @items, @id_venta OUTPUT` |
| PATCH | `/api/ventas/:id/anular` | **Anular venta** y devolver stock | `EXEC dbo.sp_anular_venta @id_venta, @motivo` |

### POST `/api/ventas` – Registrar venta

**Solicitud**
```json
{
  "id_cliente": 2,
  "id_empleado": 1,
  "metodo_pago": "YAPE",
  "items": [
    { "id_producto": 2, "cantidad": 1 },
    { "id_producto": 7, "cantidad": 1 }
  ]
}
```

**SQL que ejecuta la API**
```sql
DECLARE @id_venta INT;
EXEC dbo.sp_registrar_venta
     @id_cliente  = 2,
     @id_empleado = 1,
     @metodo_pago = 'YAPE',
     @items       = N'[{"id_producto": 2, "cantidad": 1}, {"id_producto": 7, "cantidad": 1}]',
     @id_venta    = @id_venta OUTPUT;
```

**Pasos de la transacción `sp_registrar_venta`**
1. Valida que existan el cliente, el empleado y al menos un producto.
2. Define el comprobante: RUC → FACTURA `F001`; DNI/CE → BOLETA `B001`.
3. `BEGIN TRANSACTION` y toma el siguiente número de la serie con `UPDATE ... SET @numero = ultimo_numero = ultimo_numero + 1`.
4. Inserta la cabecera en `ventas`.
5. Valida el stock de todos los productos (con bloqueo `UPDLOCK`), lo descuenta e inserta las líneas en `detalle_venta`.
6. Calcula `total`, `op_gravada = total / 1.18` e `igv` y actualiza la cabecera.
7. `COMMIT`. Si algo falla en cualquier paso, el bloque `TRY...CATCH` hace `ROLLBACK` y no se guarda nada.

**Respuesta 201**
```json
{
  "id_venta": 5,
  "comprobante": "B001-00000003",
  "tipo_comprobante": "BOLETA",
  "cliente": "María Elena Rojas Huamán",
  "vendedor": "Luis Torres Vargas",
  "detalle": [
    { "item": 1, "descripcion": "Laptop Victus 15 HP",      "cantidad": 1, "precio_unitario": 3899.00, "importe": 3899.00 },
    { "item": 2, "descripcion": "Mouse gamer G203 Logitech", "cantidad": 1, "precio_unitario": 89.90,   "importe": 89.90 }
  ],
  "op_gravada": 3380.42,
  "igv": 608.48,
  "total": 3988.90,
  "metodo_pago": "YAPE",
  "estado": "PAGADA"
}
```

**Respuesta 409 – sin stock**
```json
{ "error": "Stock insuficiente para PC Gamer Ryzen 5 (disponible: 5)" }
```

### PATCH `/api/ventas/:id/anular`

**Solicitud**
```json
{ "motivo": "Cliente desistió de la compra" }
```

**SQL:** `EXEC dbo.sp_anular_venta @id_venta = 5, @motivo = 'Cliente desistió de la compra';`
Devuelve al stock las unidades de cada producto y cambia el estado a `ANULADA` dentro de una transacción.

## 7. Reportes

| Método | Ruta | Descripción | SQL / Procedimiento |
|--------|------|-------------|---------------------|
| GET | `/api/reportes/ventas-por-mes` | Ventas, op. gravada, IGV y total por mes | `EXEC dbo.sp_reporte_ventas_por_mes` |
| GET | `/api/reportes/productos-mas-vendidos?limite=5` | Ranking de productos | `EXEC dbo.sp_reporte_productos_mas_vendidos @limite` |
| GET | `/api/reportes/ventas-por-vendedor` | Desempeño de cada vendedor | `EXEC dbo.sp_reporte_ventas_por_vendedor` |
| GET | `/api/reportes/stock-bajo` | Productos para reponer | `SELECT * FROM dbo.vw_stock_bajo` |
| GET | `/api/reportes/comprobantes` | Todas las ventas en formato comprobante | `SELECT * FROM dbo.vw_comprobantes ORDER BY fecha DESC` |

---

## Resumen de procedimientos almacenados

| Procedimiento | Tipo | Ruta |
|---------------|------|------|
| `sp_registrar_venta` | Transacción | POST `/api/ventas` |
| `sp_anular_venta` | Transacción | PATCH `/api/ventas/:id/anular` |
| `sp_ingresar_stock` | Actualización | PATCH `/api/productos/:id/stock` |
| `sp_listar_productos` | Consulta | GET `/api/productos` |
| `sp_ver_comprobante` | Consulta | GET `/api/ventas/:id` |
| `sp_historial_cliente` | Consulta | GET `/api/clientes/:id/ventas` |
| `sp_ventas_por_rango` | Consulta | GET `/api/ventas` |
| `sp_reporte_ventas_por_mes` | Reporte | GET `/api/reportes/ventas-por-mes` |
| `sp_reporte_productos_mas_vendidos` | Reporte | GET `/api/reportes/productos-mas-vendidos` |
| `sp_reporte_ventas_por_vendedor` | Reporte | GET `/api/reportes/ventas-por-vendedor` |

Código completo: [`sql/03_procedimientos_almacenados.sql`](../sql/03_procedimientos_almacenados.sql)
