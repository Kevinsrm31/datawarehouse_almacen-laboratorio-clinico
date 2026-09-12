-- =====================================================================
--  MIGRACION OLTP -> OLAP  |  almacen_laboratorio_clinico -> dw_almacen_lab
-- =====================================================================
--  Autor     : Kevin Reyes Morocho
--  Motor     : MySQL / MariaDB
--
--  REQUISITOS PREVIOS (ejecutar en este orden ANTES que este script):
--    1) sql/00_oltp_almacen_laboratorio.sql -> crea y llena el OLTP
--    2) sql/01_dw_almacen_lab_ddl.sql        -> crea el esquema dw_almacen_lab
--
--  No se inventa ningun dato transaccional ni se modifica el OLTP: la
--  tabla Movimiento ya tiene el grano exacto que necesita FactMovimiento,
--  asi que toda la carga es ETL real (extraida tal cual del OLTP). Lo
--  unico que se genera es la dimension de tiempo (dimTiempo), como es
--  practica estandar en todo Data Warehouse.
-- =====================================================================

USE dw_almacen_lab;

-- ---------------------------------------------------------------------
-- 1) CARGA DE dimProducto  (copia real desde el OLTP)
-- ---------------------------------------------------------------------
INSERT INTO dimProducto (productoID, nombreProducto, unidadMedida, stockMinimo)
SELECT productoID, nombreProducto, unidadMedida, stockMinimo
FROM almacen_laboratorio_clinico.Producto;

-- ---------------------------------------------------------------------
-- 2) CARGA DE dimUsuario  (copia real desde el OLTP)
-- ---------------------------------------------------------------------
INSERT INTO dimUsuario (usuarioID, nombreUsuario, area)
SELECT usuarioID, nombreUsuario, area
FROM almacen_laboratorio_clinico.Usuario;

-- ---------------------------------------------------------------------
-- 3) CARGA DE dimProveedor  (copia real; catalogo, no se une a hechos)
-- ---------------------------------------------------------------------
INSERT INTO dimProveedor (proveedorID, razonSocial, ruc, telefono)
SELECT proveedorID, razonSocial, ruc, telefono
FROM almacen_laboratorio_clinico.Proveedor;

-- ---------------------------------------------------------------------
-- 4) CARGA DE Producto_Proveedor  (puente de catalogo, copia real)
-- ---------------------------------------------------------------------
INSERT INTO Producto_Proveedor (productoID, proveedorID)
SELECT productoID, proveedorID
FROM almacen_laboratorio_clinico.Producto_Proveedor;

-- ---------------------------------------------------------------------
-- 5) CARGA DE dimTiempo  (generada: calendario completo del anio 2026)
-- ---------------------------------------------------------------------
-- No existe como tabla en el OLTP. Se genera con una CTE recursiva que
-- crea una fila por cada dia del anio, para poder analizar los
-- movimientos por mes, trimestre, dia de semana, etc.

INSERT INTO dimTiempo (fechaID, fecha, anio, mes, nombreMes, dia, trimestre, diaSemana, nombreDiaSemana)
WITH RECURSIVE calendario AS (
    SELECT DATE('2026-01-01') AS fecha
    UNION ALL
    SELECT fecha + INTERVAL 1 DAY FROM calendario WHERE fecha < '2026-12-31'
)
SELECT
    CAST(DATE_FORMAT(fecha, '%Y%m%d') AS UNSIGNED)          AS fechaID,
    fecha,
    YEAR(fecha),
    MONTH(fecha),
    ELT(MONTH(fecha), 'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                       'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'),
    DAY(fecha),
    QUARTER(fecha),
    WEEKDAY(fecha) + 1,                                      -- 1=lunes ... 7=domingo
    ELT(WEEKDAY(fecha) + 1, 'Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo')
FROM calendario;

-- ---------------------------------------------------------------------
-- 6) CARGA DE FactMovimiento  (ETL real, extraido tal cual del OLTP)
-- ---------------------------------------------------------------------
-- Un movimiento de Movimiento = una fila de FactMovimiento (mismo
-- grano). cantidadEntrada/cantidadSalida se derivan de tipoMovimiento
-- para poder calcular stock neto con SUM(cantidadEntrada - cantidadSalida)
-- sin tener que filtrar por tipo en cada consulta.

INSERT INTO FactMovimiento (movimientoID, productoID, usuarioID, fechaID, tipoMovimiento, cantidad, cantidadEntrada, cantidadSalida)
SELECT
    m.movimientoID,
    m.productoID,
    m.usuarioID,
    CAST(DATE_FORMAT(m.fechaMovimiento, '%Y%m%d') AS UNSIGNED),
    m.tipoMovimiento,
    m.cantidad,
    CASE WHEN m.tipoMovimiento = 'ENTRADA' THEN m.cantidad ELSE 0 END,
    CASE WHEN m.tipoMovimiento = 'SALIDA'  THEN m.cantidad ELSE 0 END
FROM almacen_laboratorio_clinico.Movimiento m;

-- ---------------------------------------------------------------------
-- 7) VALIDACIONES POST-CARGA
-- ---------------------------------------------------------------------
SELECT 'dimProducto' AS tabla, COUNT(*) AS filas FROM dimProducto
UNION ALL SELECT 'dimUsuario', COUNT(*) FROM dimUsuario
UNION ALL SELECT 'dimProveedor', COUNT(*) FROM dimProveedor
UNION ALL SELECT 'Producto_Proveedor', COUNT(*) FROM Producto_Proveedor
UNION ALL SELECT 'dimTiempo', COUNT(*) FROM dimTiempo
UNION ALL SELECT 'FactMovimiento', COUNT(*) FROM FactMovimiento;

-- Integridad referencial: no deben existir hechos huerfanos
SELECT COUNT(*) AS mov_sin_producto
FROM FactMovimiento f LEFT JOIN dimProducto d ON f.productoID = d.productoID
WHERE d.productoID IS NULL;

SELECT COUNT(*) AS mov_sin_usuario
FROM FactMovimiento f LEFT JOIN dimUsuario d ON f.usuarioID = d.usuarioID
WHERE d.usuarioID IS NULL;

SELECT COUNT(*) AS mov_sin_fecha
FROM FactMovimiento f LEFT JOIN dimTiempo d ON f.fechaID = d.fechaID
WHERE d.fechaID IS NULL;

-- Hallazgo de calidad de datos: productos con stock neto negativo
-- (mas detalle de este hallazgo en la documentacion adjunta)
SELECT dp.nombreProducto,
       SUM(f.cantidadEntrada) AS entradas,
       SUM(f.cantidadSalida)  AS salidas,
       SUM(f.cantidadEntrada) - SUM(f.cantidadSalida) AS stock_neto
FROM FactMovimiento f JOIN dimProducto dp ON f.productoID = dp.productoID
GROUP BY dp.nombreProducto
ORDER BY stock_neto ASC;
