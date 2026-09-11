CREATE DATABASE almacen_laboratorio_clinico;

USE almacen_laboratorio_clinico;

/* CREAMOS LA TABLA Producto */

CREATE TABLE Producto (

productoID VARCHAR(8) PRIMARY KEY NOT NULL,

nombreProducto VARCHAR(100) NOT NULL,

unidadMedida VARCHAR(20) DEFAULT NULL,

stockMinimo INT DEFAULT NULL

);

/* CREAMOS LA TABLA Proveedor */

CREATE TABLE Proveedor (

proveedorID VARCHAR(8) PRIMARY KEY NOT NULL,

razonSocial VARCHAR(100) NOT NULL,

ruc VARCHAR(11) DEFAULT NULL,

telefono VARCHAR(20) DEFAULT NULL

);

/* CREAMOS LA TABLA Usuario */

CREATE TABLE Usuario (

usuarioID VARCHAR(8) PRIMARY KEY NOT NULL,

nombreUsuario VARCHAR(100) NOT NULL,

area VARCHAR(50) DEFAULT NULL

);

# CREAMOS LA TABLA Producto_Proveedor (relacion N:M entre Producto y Proveedor)

CREATE TABLE Producto_Proveedor (

productoID VARCHAR(8) NOT NULL,

proveedorID VARCHAR(8) NOT NULL,

PRIMARY KEY (productoID, proveedorID),

CONSTRAINT fk_prodprov_producto FOREIGN KEY (productoID) REFERENCES Producto (productoID),

CONSTRAINT fk_prodprov_proveedor FOREIGN KEY (proveedorID) REFERENCES Proveedor (proveedorID)

);

## CREANDO LA TABLA Movimiento (relacion "registra" entre Usuario y Producto, con atributos propios)

CREATE TABLE Movimiento (

movimientoID INT AUTO_INCREMENT PRIMARY KEY,

productoID VARCHAR(8) NOT NULL,

usuarioID VARCHAR(8) NOT NULL,

tipoMovimiento VARCHAR(10) NOT NULL,

cantidad INT NOT NULL,

fechaMovimiento DATE NOT NULL,

CONSTRAINT fk_movimiento_producto FOREIGN KEY (productoID) REFERENCES Producto (productoID),

CONSTRAINT fk_movimiento_usuario FOREIGN KEY (usuarioID) REFERENCES Usuario (usuarioID)

);

# insertando valores a la tabla Producto

INSERT INTO Producto VALUES

("PR000001","Reactivo Glucosa","Caja",10),

("PR000002","Guantes de nitrilo","Caja",50),

("PR000003","Tubo de ensayo EDTA","Unidad",200);

# insertando valores a la tabla Proveedor

INSERT INTO Proveedor VALUES

("PV000001","Diagnostica SAC","20456789123","014567890"),

("PV000002","BioInsumos Peru EIRL","20567891234","016789012"),

("PV000003","LabSupply Import SA","20678912345","017890123");

# insertando valores a la tabla Usuario

INSERT INTO Usuario VALUES

("US000001","Carla Ramos Diaz","Almacen"),

("US000002","Jorge Salinas Vega","Bioquimica"),

("US000003","Lucia Fernandez Rojas","Hematologia");

# insertando valores a la tabla Producto_Proveedor

INSERT INTO Producto_Proveedor VALUES

("PR000001","PV000001"),

("PR000001","PV000002"),

("PR000002","PV000002"),

("PR000003","PV000003");

# insertando valores a la tabla Movimiento
# NOTA: se agrega la ENTRADA de PR000002 del 2026-07-15, que faltaba en
# el dataset original. Sin ella, Guantes de nitrilo quedaba con stock
# neto negativo (-5), porque tenia una SALIDA sin ninguna ENTRADA previa
# que la respalde -- algo imposible en un almacen real.

INSERT INTO Movimiento (productoID, usuarioID, tipoMovimiento, cantidad, fechaMovimiento) VALUES

("PR000002","US000001","ENTRADA",60,"2026-07-15"),

("PR000001","US000001","ENTRADA",30,"2026-08-01"),

("PR000002","US000002","SALIDA",5,"2026-08-03"),

("PR000003","US000001","ENTRADA",100,"2026-08-05"),

("PR000001","US000003","SALIDA",8,"2026-08-07");
