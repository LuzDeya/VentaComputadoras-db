# 2. Diccionario de datos

Base de datos: `tienda_computadoras` · Motor: SQL Server 2016+ · Intercalación: `Modern_Spanish_CI_AS` · Moneda: soles (S/)

Abreviaturas: **PK** llave primaria · **FK** llave foránea · **UQ** único · **IDENTITY** autoincremental (IDENTITY(1,1)) · **NN** no nulo

---

## 2.1 `categorias`
Clasificación de los productos.

| Columna | Tipo | Nulo | Llave | Por defecto | Restricción | Descripción |
|---------|------|:----:|:-----:|-------------|-------------|-------------|
| id_categoria | INT | NN | PK, IDENTITY | | | Identificador |
| nombre | VARCHAR(50) | NN | UQ | | | Laptops, PC de escritorio, Monitores… |
| descripcion | VARCHAR(150) | Sí | | NULL | | Descripción |

## 2.2 `proveedores`
Empresas que abastecen los productos.

| Columna | Tipo | Nulo | Llave | Por defecto | Restricción | Descripción |
|---------|------|:----:|:-----:|-------------|-------------|-------------|
| id_proveedor | INT | NN | PK, IDENTITY | | | Identificador |
| ruc | CHAR(11) | NN | UQ | | 11 dígitos, inicia en 10 o 20 | RUC |
| razon_social | VARCHAR(120) | NN | | | | Nombre legal |
| contacto | VARCHAR(100) | Sí | | NULL | | Persona de contacto |
| telefono | VARCHAR(15) | Sí | | NULL | | Teléfono |
| email | VARCHAR(100) | Sí | | NULL | formato de correo | Correo de pedidos |
| direccion | VARCHAR(150) | Sí | | NULL | | Dirección fiscal |
| activo | BIT | NN | | 1 | 0 o 1 | Si se le sigue comprando |

## 2.3 `productos`
Computadoras, monitores, periféricos y componentes a la venta.

| Columna | Tipo | Nulo | Llave | Por defecto | Restricción | Descripción |
|---------|------|:----:|:-----:|-------------|-------------|-------------|
| id_producto | INT | NN | PK, IDENTITY | | | Identificador |
| codigo | VARCHAR(20) | NN | UQ | | | SKU comercial (ej. `LAP-HP-VIC15`) |
| nombre | VARCHAR(100) | NN | | | | Nombre del producto |
| marca | VARCHAR(50) | NN | | | | Lenovo, HP, ASUS, LG… |
| modelo | VARCHAR(50) | Sí | | NULL | | Modelo del fabricante |
| procesador | VARCHAR(60) | Sí | | NULL | | Solo laptops y PC |
| ram_gb | SMALLINT | Sí | | NULL | > 0 | Memoria RAM en GB |
| almacenamiento | VARCHAR(40) | Sí | | NULL | | Ej. 512 GB SSD |
| pantalla | VARCHAR(40) | Sí | | NULL | | Ej. 15.6" FHD |
| gpu | VARCHAR(60) | Sí | | NULL | | Tarjeta de video |
| descripcion | VARCHAR(255) | Sí | | NULL | | Otras características |
| precio_compra | DECIMAL(10,2) | NN | | | ≥ 0 | Costo unitario |
| precio_venta | DECIMAL(10,2) | NN | | | ≥ precio_compra | Precio unitario con IGV |
| stock | INT | NN | | 0 | ≥ 0 | Unidades disponibles |
| stock_minimo | INT | NN | | 0 | ≥ 0 | Alerta de reposición |
| garantia_meses | TINYINT | NN | | 12 | ≥ 0 | Meses de garantía |
| activo | BIT | NN | | 1 | 0 o 1 | Si aparece en el catálogo |
| id_categoria | INT | NN | FK | | → categorias | Categoría |
| id_proveedor | INT | NN | FK | | → proveedores | Proveedor |

## 2.4 `clientes`
Personas o empresas que compran.

| Columna | Tipo | Nulo | Llave | Por defecto | Restricción | Descripción |
|---------|------|:----:|:-----:|-------------|-------------|-------------|
| id_cliente | INT | NN | PK, IDENTITY | | | Identificador |
| tipo_documento | VARCHAR(3) | NN | UQ (compuesta) | | IN ('DNI','RUC','CE') | Tipo de documento |
| numero_documento | VARCHAR(12) | NN | UQ (compuesta) | | DNI 8 dígitos, RUC 11, CE 9–12 | Número de documento |
| nombre | VARCHAR(120) | NN | | | | Nombres y apellidos o razón social |
| direccion | VARCHAR(150) | Sí | | NULL | | Dirección |
| telefono | VARCHAR(15) | Sí | | NULL | | Teléfono o celular |
| email | VARCHAR(100) | Sí | | NULL | formato de correo | Correo |
| fecha_registro | DATETIME | NN | | GETDATE() | | Fecha de alta |

## 2.5 `empleados`
Personal que registra las ventas.

| Columna | Tipo | Nulo | Llave | Por defecto | Restricción | Descripción |
|---------|------|:----:|:-----:|-------------|-------------|-------------|
| id_empleado | INT | NN | PK, IDENTITY | | | Identificador |
| dni | CHAR(8) | NN | UQ | | 8 dígitos | DNI |
| nombres | VARCHAR(100) | NN | | | | Nombres y apellidos |
| cargo | VARCHAR(15) | NN | | | IN ('VENDEDOR','CAJERO','ADMINISTRADOR') | Puesto |
| email | VARCHAR(100) | Sí | | NULL | | Correo corporativo |
| activo | BIT | NN | | 1 | 0 o 1 | Si puede registrar ventas |

## 2.6 `series_comprobante`
Controla el correlativo de boletas y facturas.

| Columna | Tipo | Nulo | Llave | Por defecto | Restricción | Descripción |
|---------|------|:----:|:-----:|-------------|-------------|-------------|
| serie | CHAR(4) | NN | PK | | B### para boleta, F### para factura | Serie |
| tipo_comprobante | VARCHAR(7) | NN | | | IN ('BOLETA','FACTURA') | Tipo |
| ultimo_numero | INT | NN | | 0 | ≥ 0 | Último número emitido |

## 2.7 `ventas`
Cabecera del comprobante de venta.

| Columna | Tipo | Nulo | Llave | Por defecto | Restricción | Descripción |
|---------|------|:----:|:-----:|-------------|-------------|-------------|
| id_venta | INT | NN | PK, IDENTITY | | | Identificador |
| tipo_comprobante | VARCHAR(7) | NN | | | IN ('BOLETA','FACTURA') | Tipo de comprobante |
| serie | CHAR(4) | NN | FK, UQ (compuesta) | | → series_comprobante | Serie |
| numero | INT | NN | UQ (compuesta) | | > 0 | Correlativo |
| fecha | DATETIME | NN | | GETDATE() | | Fecha y hora |
| id_cliente | INT | NN | FK | | → clientes | Cliente |
| id_empleado | INT | NN | FK | | → empleados | Vendedor |
| op_gravada | DECIMAL(12,2) | NN | | 0 | ≥ 0 | Valor de venta sin IGV |
| igv | DECIMAL(12,2) | NN | | 0 | ≥ 0 | IGV 18 % |
| total | DECIMAL(12,2) | NN | | 0 | = op_gravada + igv | Importe total |
| metodo_pago | VARCHAR(15) | NN | | | IN ('EFECTIVO','TARJETA','YAPE','PLIN','TRANSFERENCIA') | Forma de pago |
| estado | VARCHAR(7) | NN | | 'PAGADA' | IN ('PAGADA','ANULADA') | Estado |
| motivo_anulacion | VARCHAR(200) | Sí | | NULL | | Solo si fue anulada |

## 2.8 `detalle_venta`
Productos incluidos en cada venta.

| Columna | Tipo | Nulo | Llave | Por defecto | Restricción | Descripción |
|---------|------|:----:|:-----:|-------------|-------------|-------------|
| id_venta | INT | NN | PK, FK | | → ventas (CASCADE) | Venta |
| item | SMALLINT | NN | PK | | > 0 | Número de línea |
| id_producto | INT | NN | FK | | → productos | Producto vendido |
| cantidad | INT | NN | | | > 0 | Unidades |
| precio_unitario | DECIMAL(10,2) | NN | | | ≥ 0 | Precio al momento de la venta |
| importe | DECIMAL(12,2) | NN | | | = cantidad × precio_unitario | Subtotal de la línea |

---

## 2.9 Índices

| Tabla | Índice | Columnas | Uso |
|-------|--------|----------|-----|
| productos | ix_productos_categoria_precio | id_categoria, precio_venta | Catálogo filtrado por categoría y precio |
| productos | ix_productos_marca | marca | Filtro por marca |
| ventas | ix_ventas_fecha | fecha | Ventas por rango de fechas y reporte mensual |
| ventas | ix_ventas_cliente_fecha | id_cliente, fecha | Historial de compras del cliente |
| ventas | ix_ventas_empleado_fecha | id_empleado, fecha | Ventas por vendedor |
| productos | ix_productos_proveedor | id_proveedor | Productos por proveedor (FK) |
| detalle_venta | ix_detalle_producto | id_producto | Productos más vendidos (FK) |

SQL Server crea automáticamente un índice por cada PRIMARY KEY y UNIQUE. Las llaves foráneas no se indexan solas, por eso se crean los índices de la tabla anterior.

## 2.10 Vistas

| Vista | Descripción |
|-------|-------------|
| `vw_comprobantes` | Ventas con el comprobante en formato `B001-00000001`, nombre del cliente y del vendedor. |
| `vw_stock_bajo` | Productos activos con `stock ≤ stock_minimo` y datos del proveedor para reponer. |
