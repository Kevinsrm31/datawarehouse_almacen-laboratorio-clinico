-- =====================================================================
--  DDL DATA WAREHOUSE  |  dw_almacen_lab
-- =====================================================================
--  Autor     : Kevin Reyes Morocho
--  Motor     : MySQL / MariaDB
--  Proposito : Esquema dimensional (estrella) para analizar los
--              movimientos de inventario del almacen de un laboratorio
--              clinico (entradas y salidas de productos).
--
--  Proceso de negocio elegido / grano de la tabla de hechos:
--    1 fila de FactMovimiento = 1 movimiento de inventario
--    (la misma granularidad que ya trae la tabla Movimiento del OLTP).
--
--  Diseno: este Data Warehouse se construye sobre el OLTP incluido en
--  sql/00_oltp_almacen_laboratorio.sql, sin modificar su esquema. El
--  OLTP no registra que proveedor entrego cada movimiento puntual -- la
--  unica relacion disponible es Producto_Proveedor (que proveedores
--  PUEDEN surtir cada producto). Por eso dimProveedor se conecta al
--  modelo como catalogo, a traves de Producto_Proveedor, y NO se une
--  directamente a FactMovimiento. Ver documentacion adjunta para el
--  detalle.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS dw_almacen_lab;
USE dw_almacen_lab;

-- ---------------------------------------------------------------------
-- DIMENSIONES
-- ---------------------------------------------------------------------

/* dimProducto: catalogo de productos del almacen */
CREATE TABLE dimProducto (
    productoID      VARCHAR(8)   PRIMARY KEY,
    nombreProducto  VARCHAR(100),
    unidadMedida    VARCHAR(20),
    stockMinimo     INT
);

/* dimUsuario: quien registra el movimiento */
CREATE TABLE dimUsuario (
    usuarioID       VARCHAR(8)   PRIMARY KEY,
    nombreUsuario   VARCHAR(100),
    area            VARCHAR(50)
);

/* dimProveedor: catalogo de proveedores. NO se conecta directamente a
   FactMovimiento -- el OLTP no captura que proveedor entrego cada
   movimiento puntual. Se relaciona al modelo via Producto_Proveedor. */
CREATE TABLE dimProveedor (
    proveedorID     VARCHAR(8)   PRIMARY KEY,
    razonSocial     VARCHAR(100),
    ruc             VARCHAR(11),
    telefono        VARCHAR(20)
);

/* Producto_Proveedor: puente de catalogo (N:M), migrado tal cual del
   OLTP. Responde "que proveedores PUEDEN surtir este producto" -- es
   la unica informacion de proveedor disponible a nivel de movimiento,
   ya que el OLTP no registra quien entrego cada entrada puntual. */
CREATE TABLE Producto_Proveedor (
    productoID      VARCHAR(8),
    proveedorID     VARCHAR(8),
    PRIMARY KEY (productoID, proveedorID),
    CONSTRAINT fk_pp_producto  FOREIGN KEY (productoID)  REFERENCES dimProducto (productoID),
    CONSTRAINT fk_pp_proveedor FOREIGN KEY (proveedorID) REFERENCES dimProveedor (proveedorID)
);

/* dimTiempo: dimension de fecha generada (no existe como tabla en el
   OLTP; se construye porque toda tabla de hechos con una fecha se
   beneficia de poder agrupar por mes/trimestre/anio/dia de semana) */
CREATE TABLE dimTiempo (
    fechaID         INT PRIMARY KEY,        -- formato YYYYMMDD
    fecha           DATE NOT NULL,
    anio            INT,
    mes             INT,
    nombreMes       VARCHAR(15),
    dia             INT,
    trimestre       INT,
    diaSemana       INT,                    -- 1=lunes ... 7=domingo
    nombreDiaSemana VARCHAR(15)
);

-- ---------------------------------------------------------------------
-- TABLA DE HECHOS
-- ---------------------------------------------------------------------

/* FactMovimiento: 1 fila = 1 movimiento de inventario (entrada o
   salida). cantidadEntrada/cantidadSalida son medidas derivadas que
   facilitan calcular stock neto con un simple SUM(). No incluye
   proveedor: el OLTP no lo registra a nivel de movimiento (ver nota
   de diseno arriba). */
CREATE TABLE FactMovimiento (
    movimientoID     INT PRIMARY KEY,
    productoID       VARCHAR(8)  NOT NULL,
    usuarioID        VARCHAR(8)  NOT NULL,
    fechaID          INT         NOT NULL,
    tipoMovimiento   VARCHAR(10) NOT NULL,
    cantidad         INT         NOT NULL,
    cantidadEntrada  INT         NOT NULL,
    cantidadSalida   INT         NOT NULL,

    CONSTRAINT fk_fact_producto  FOREIGN KEY (productoID)  REFERENCES dimProducto (productoID),
    CONSTRAINT fk_fact_usuario   FOREIGN KEY (usuarioID)   REFERENCES dimUsuario (usuarioID),
    CONSTRAINT fk_fact_tiempo    FOREIGN KEY (fechaID)     REFERENCES dimTiempo (fechaID)
);
