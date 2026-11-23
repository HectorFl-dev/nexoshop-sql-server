-- BASE 1: NEXOSHOP. Ejecutar todo en SSMS (SQL Server 2016 SP1+).
IF DB_ID(N'NexoShop_S14') IS NULL EXEC('CREATE DATABASE NexoShop_S14');
GO
USE NexoShop_S14;
GO
-- Script de preparación repetible: elimina objetos de laboratorio en orden de dependencias.
DROP TABLE IF EXISTS dbo.FactVenta;
DROP TABLE IF EXISTS dbo.DimFecha;
DROP TABLE IF EXISTS dbo.DimCanal;
DROP TABLE IF EXISTS dbo.DetallePedido;
DROP TABLE IF EXISTS dbo.Pago;
DROP TABLE IF EXISTS dbo.Pedido;
DROP TABLE IF EXISTS dbo.Producto;
DROP TABLE IF EXISTS dbo.Cliente;
GO
CREATE TABLE dbo.Cliente(ClienteID INT PRIMARY KEY, Nombre VARCHAR(80) NOT NULL, Ciudad VARCHAR(40) NOT NULL);
CREATE TABLE dbo.Producto(ProductoID INT PRIMARY KEY, Nombre VARCHAR(80) NOT NULL, Categoria VARCHAR(40) NOT NULL, Precio DECIMAL(10,2) NOT NULL CHECK(Precio>0), Stock INT NOT NULL CHECK(Stock>=0));
CREATE TABLE dbo.Pedido(PedidoID INT IDENTITY(1,1) PRIMARY KEY, ClienteID INT NOT NULL REFERENCES dbo.Cliente(ClienteID), Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(), Estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE' CHECK(Estado IN('PENDIENTE','PAGADO')));
CREATE TABLE dbo.DetallePedido(DetalleID INT IDENTITY(1,1) PRIMARY KEY, PedidoID INT NOT NULL REFERENCES dbo.Pedido(PedidoID), ProductoID INT NOT NULL REFERENCES dbo.Producto(ProductoID), Cantidad INT NOT NULL CHECK(Cantidad>0), PrecioUnitario DECIMAL(10,2) NOT NULL CHECK(PrecioUnitario>0));
CREATE TABLE dbo.Pago(PagoID INT IDENTITY(1,1) PRIMARY KEY, PedidoID INT NOT NULL UNIQUE REFERENCES dbo.Pedido(PedidoID), Monto DECIMAL(12,2) NOT NULL CHECK(Monto>0), Estado VARCHAR(15) NOT NULL CHECK(Estado IN('APROBADO','RECHAZADO')));
-- Modelo dimensional de lectura (estrella): FactVenta al centro; dimensiones Cliente, Producto, Fecha y Canal.
CREATE TABLE dbo.DimFecha(FechaKey INT PRIMARY KEY, Fecha DATE NOT NULL UNIQUE, Anio SMALLINT NOT NULL, Mes TINYINT NOT NULL);
CREATE TABLE dbo.DimCanal(CanalID INT PRIMARY KEY, NombreCanal VARCHAR(40) NOT NULL UNIQUE);
CREATE TABLE dbo.FactVenta(VentaKey INT IDENTITY(1,1) PRIMARY KEY, PedidoID INT NOT NULL UNIQUE REFERENCES dbo.Pedido(PedidoID), ClienteID INT NOT NULL REFERENCES dbo.Cliente(ClienteID), ProductoID INT NOT NULL REFERENCES dbo.Producto(ProductoID), FechaKey INT NOT NULL REFERENCES dbo.DimFecha(FechaKey), CanalID INT NOT NULL REFERENCES dbo.DimCanal(CanalID), Cantidad INT NOT NULL CHECK(Cantidad>0), Importe DECIMAL(12,2) NOT NULL CHECK(Importe>0));
INSERT dbo.Cliente VALUES (1,'Ana Torres','Lima'),(2,'Luis Rojas','Arequipa'),(3,'Marta León','Lima'),(4,'Carlos Díaz','Trujillo');
INSERT dbo.Producto VALUES (101,'Teclado mecánico','Periféricos',120,8),(102,'Mouse óptico','Periféricos',60,10),(103,'Monitor 24','Pantallas',650,3),(104,'Webcam HD','Video',180,0);
INSERT dbo.DimCanal VALUES(1,'Web'),(2,'Aplicación');
INSERT dbo.DimFecha VALUES(20261114,'20261114',2026,11),(20261115,'20261115',2026,11);
-- Historial de referencia coherente: pedido pagado, detalle, pago, fact y stock ya descontado en los valores iniciales.
SET IDENTITY_INSERT dbo.Pedido ON;
INSERT dbo.Pedido(PedidoID,ClienteID,Fecha,Estado) VALUES(100,1,'2026-11-14T09:00:00','PAGADO');
SET IDENTITY_INSERT dbo.Pedido OFF;
INSERT dbo.DetallePedido(PedidoID,ProductoID,Cantidad,PrecioUnitario) VALUES(100,102,1,60);
INSERT dbo.Pago(PedidoID,Monto,Estado) VALUES(100,60,'APROBADO');
INSERT dbo.FactVenta(PedidoID,ClienteID,ProductoID,FechaKey,CanalID,Cantidad,Importe) VALUES(100,1,102,20261114,1,1,60);
GO
SELECT 'Cliente' Tabla,COUNT(*) Total FROM dbo.Cliente UNION ALL SELECT 'Producto',COUNT(*) FROM dbo.Producto UNION ALL SELECT 'Pedido',COUNT(*) FROM dbo.Pedido UNION ALL SELECT 'FactVenta',COUNT(*) FROM dbo.FactVenta;
-- Diagrama SSMS: Database Diagrams > New Database Diagram > agregar las 9 tablas.
-- SQL Server muestra las relaciones FK, NO dibuja automáticamente una estrella física perfecta.



----
USE NexoShop_S14;
GO

---ACTIVIDAD 1: VERIFICACIÓN DE TABLAS Y CONTEOS INICIALES
DECLARE @sql NVARCHAR(MAX) = N'';
DECLARE @totalTablas INT;

-- Obtener el número total de tablas de usuario
SELECT @totalTablas = COUNT(*) FROM sys.tables;

-- Generar dinámicamente el UNION ALL para contar filas de cada tabla
SELECT @sql = @sql + STUFF((
    SELECT ' UNION ALL SELECT ''' + t.name + ''' AS Tabla, COUNT(*) AS TotalFilas FROM dbo.' + QUOTENAME(t.name)
    FROM sys.tables t
    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 11, '');

EXEC sp_executesql @sql;
SELECT @totalTablas AS NumeroTotalDeTablas;
GO


---EJERCICIO 1: CONSULTA REUTILIZABLE (dbo.usp_ProductosDisponibles)
CREATE OR ALTER PROCEDURE dbo.usp_ProductosDisponibles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ProductoID, Nombre, Precio, Stock
    FROM dbo.Producto
    WHERE Stock > 0
    ORDER BY Nombre;
END;
GO

-- Pruebas: ejecutar dos veces y comparar
EXEC dbo.usp_ProductosDisponibles;
EXEC dbo.usp_ProductosDisponibles;
GO


---EJERCICIO 2: PARÁMETRO DE ENTRADA (dbo.usp_ProductosPorCategoria)
CREATE OR ALTER PROCEDURE dbo.usp_ProductosPorCategoria
    @Categoria VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ProductoID, Nombre, Precio, Stock
    FROM dbo.Producto
    WHERE Categoria = @Categoria;
END;
GO

-- Pruebas solicitadas por la guía
EXEC dbo.usp_ProductosPorCategoria @Categoria = 'Periféricos';
EXEC dbo.usp_ProductosPorCategoria @Categoria = 'Pantallas';
EXEC dbo.usp_ProductosPorCategoria @Categoria = 'Inexistente'; -- Devuelve 0 filas (conjunto vacío sin error)
GO



---EJERCICIO 3: PARÁMETRO OUTPUT (dbo.usp_TotalPedidosCliente)
CREATE OR ALTER PROCEDURE dbo.usp_TotalPedidosCliente
    @ClienteID INT,
    @Total INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT @Total = COUNT(*)
    FROM dbo.Pedido
    WHERE ClienteID = @ClienteID;
END;
GO

-- Prueba para ClienteID = 1 (según guía) y ClienteID = 2
DECLARE @resultado INT;

EXEC dbo.usp_TotalPedidosCliente 
    @ClienteID = 1, 
    @Total = @resultado OUTPUT;
SELECT @resultado AS TotalPedidos_Cliente1;

EXEC dbo.usp_TotalPedidosCliente 
    @ClienteID = 2, 
    @Total = @resultado OUTPUT;
SELECT @resultado AS TotalPedidos_Cliente2;
GO



---EJERCICIO 4: CHECKOUT BÁSICO SIN TRANSACCIÓN (dbo.usp_PedidoBasico)
CREATE OR ALTER PROCEDURE dbo.usp_PedidoBasico
    @ClienteID INT,
    @ProductoID INT,
    @Cantidad INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validaciones (códigos >= 50000 requeridos por THROW en T-SQL)
    IF @Cantidad <= 0
        THROW 50001, 'CANTIDAD INVALIDA.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ClienteID)
        THROW 50002, 'CLIENTE INEXISTENTE.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE ProductoID = @ProductoID)
        THROW 50003, 'PRODUCTO INEXISTENTE.', 1;
        
    -- 1. Registrar Pedido
    INSERT INTO dbo.Pedido (ClienteID)
    VALUES (@ClienteID);

    DECLARE @id INT = CONVERT(INT, SCOPE_IDENTITY());

    -- 2. Registrar Detalle
    INSERT INTO dbo.DetallePedido (PedidoID, ProductoID, Cantidad, PrecioUnitario)
    SELECT @id, @ProductoID, @Cantidad, Precio
    FROM dbo.Producto
    WHERE ProductoID = @ProductoID;

    -- 3. Descontar Inventario (punto crítico si falla)
    UPDATE dbo.Producto
    SET Stock = Stock - @Cantidad
    WHERE ProductoID = @ProductoID;
END;
GO

-- Bloque de prueba controlado para evidenciar el fallo parcial (autocommit)
BEGIN TRANSACTION;

BEGIN TRY
    EXEC dbo.usp_PedidoBasico
        @ClienteID = 2,
        @ProductoID = 101,
        @Cantidad = 101; -- Fuerza error CHECK (Stock >= 0) en el UPDATE final
END TRY
BEGIN CATCH
    SELECT 
        ERROR_NUMBER() AS CodigoError,
        ERROR_MESSAGE() AS MensajeError;
END CATCH;

-- Evidencia de inconsistencia: el Pedido y Detalle SÍ se insertaron, pero el Stock NO bajó
SELECT PedidoID, ClienteID, Estado FROM dbo.Pedido;
SELECT DetalleID, PedidoID, ProductoID, Cantidad FROM dbo.DetallePedido;
SELECT ProductoID, Nombre, Stock FROM dbo.Producto WHERE ProductoID = 101;

-- Revertir la transacción externa para dejar la BD limpia antes del Ejercicio 5
IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION;
GO



---EJERCICIO 5: EXTENSIÓN SEGURA CON TRANSACCIÓN (dbo.usp_CheckoutSeguro)

USE NexoShop_S14;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CheckoutSeguro
    @ClienteID INT,
    @ProductoID INT,
    @Cantidad INT,
    @CanalID INT = 1,
    @FechaKey INT = 20261115,
    @SimularFallo BIT = 0,
    @PedidoNuevo INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PrecioUnitario DECIMAL(10,2);
    DECLARE @StockActual INT;
    DECLARE @ImporteTotal DECIMAL(12,2);

    -- 1. Validaciones previas
    IF @Cantidad <= 0
        THROW 50001, 'Cantidad inválida. Debe ser mayor a 0.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ClienteID)
        THROW 50002, 'Cliente inexistente.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.DimCanal WHERE CanalID = @CanalID)
        THROW 50003, 'Canal de venta inexistente.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.DimFecha WHERE FechaKey = @FechaKey)
        THROW 50004, 'FechaKey no registrada en DimFecha.', 1;

    SELECT 
        @PrecioUnitario = Precio,
        @StockActual = Stock
    FROM dbo.Producto
    WHERE ProductoID = @ProductoID;

    IF @PrecioUnitario IS NULL
        THROW 50005, 'Producto inexistente.', 1;

    IF @StockActual < @Cantidad
        THROW 50006, 'Stock insuficiente para completar el pedido.', 1;

    SET @ImporteTotal = @PrecioUnitario * @Cantidad;

    -- 2. Bloque transaccional protegido
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Descontar stock
        UPDATE dbo.Producto
        SET Stock = Stock - @Cantidad
        WHERE ProductoID = @ProductoID
          AND Stock >= @Cantidad;

        IF @@ROWCOUNT = 0
            THROW 50007, 'Conflicto de concurrencia: stock agotado durante la operación.', 1;

        -- Registrar Pedido confirmado
        INSERT INTO dbo.Pedido (ClienteID, Estado)
        VALUES (@ClienteID, 'PAGADO');

        SET @PedidoNuevo = CONVERT(INT, SCOPE_IDENTITY());

        -- Registrar DetallePedido
        INSERT INTO dbo.DetallePedido (PedidoID, ProductoID, Cantidad, PrecioUnitario)
        VALUES (@PedidoNuevo, @ProductoID, @Cantidad, @PrecioUnitario);

        -- Registrar Pago aprobado
        INSERT INTO dbo.Pago (PedidoID, Monto, Estado)
        VALUES (@PedidoNuevo, @ImporteTotal, 'APROBADO');

        -- Simulación de fallo antes del COMMIT (para pruebas de ROLLBACK)
        IF @SimularFallo = 1
            THROW 50099, 'Fallo simulado antes de confirmar la transacción.', 1;

        -- Registrar en tabla de hechos (FactVenta)
        INSERT INTO dbo.FactVenta (PedidoID, ClienteID, ProductoID, FechaKey, CanalID, Cantidad, Importe)
        VALUES (@PedidoNuevo, @ClienteID, @ProductoID, @FechaKey, @CanalID, @Cantidad, @ImporteTotal);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @PedidoNuevo = NULL;
        THROW;
    END CATCH;
END;
GO



---EJERCICIO 6: PRUEBAS DE INTEGRIDAD (ÉXITO, ROLLBACK Y VALIDACIONES)

-- PRUEBA 1: Venta exitosa de 2 teclados (ProductoID = 101) a ClienteID = 2
USE NexoShop_S14;
GO

DECLARE @NuevoID INT;

EXEC dbo.usp_CheckoutSeguro
    @ClienteID = 2,
    @ProductoID = 101,
    @Cantidad = 2,
    @CanalID = 1,
    @FechaKey = 20261115,
    @SimularFallo = 0,
    @PedidoNuevo = @NuevoID OUTPUT;

SELECT @NuevoID AS PedidoGenerado_Exito;

-- Verificar estado tras compra exitosa (Stock baja de 8 a 6; se crean Pedido, Pago y FactVenta)
SELECT ProductoID, Nombre, Stock FROM dbo.Producto WHERE ProductoID = 101;
SELECT * FROM dbo.Pedido;
SELECT * FROM dbo.Pago;
SELECT * FROM dbo.FactVenta;
GO

-- PRUEBA 2: Repetir venta con @SimularFallo = 1 (Comprobar ROLLBACK total)
BEGIN TRY
    DECLARE @IDFallido INT;
    EXEC dbo.usp_CheckoutSeguro
        @ClienteID = 2,
        @ProductoID = 101,
        @Cantidad = 2,
        @SimularFallo = 1,
        @PedidoNuevo = @IDFallido OUTPUT;
END TRY
BEGIN CATCH
    SELECT 
        ERROR_NUMBER() AS ErrorSimulado, 
        ERROR_MESSAGE() AS MensajeError;
END CATCH;

-- Verificar que el Stock sigue en 6 y los conteos NO aumentaron
SELECT ProductoID, Nombre, Stock FROM dbo.Producto WHERE ProductoID = 101;
SELECT COUNT(*) AS TotalPedidos FROM dbo.Pedido;
SELECT COUNT(*) AS TotalPagos FROM dbo.Pago;
SELECT COUNT(*) AS TotalFactVenta FROM dbo.FactVenta;
GO

-- PRUEBA 3: Cantidad excesiva (pide 50 teclados, solo quedan 6)
BEGIN TRY
    DECLARE @IDExceso INT;
    EXEC dbo.usp_CheckoutSeguro
        @ClienteID = 2,
        @ProductoID = 101,
        @Cantidad = 50,
        @SimularFallo = 0,
        @PedidoNuevo = @IDExceso OUTPUT;
END TRY
BEGIN CATCH
    SELECT 
        ERROR_NUMBER() AS ErrorStock, 
        ERROR_MESSAGE() AS MensajeError;
END CATCH;
GO

-- PRUEBA 4: Cliente inexistente (ClienteID = 999)
BEGIN TRY
    DECLARE @IDClienteInv INT;
    EXEC dbo.usp_CheckoutSeguro
        @ClienteID = 999,
        @ProductoID = 101,
        @Cantidad = 1,
        @SimularFallo = 0,
        @PedidoNuevo = @IDClienteInv OUTPUT;
END TRY
BEGIN CATCH
    SELECT 
        ERROR_NUMBER() AS ErrorCliente, 
        ERROR_MESSAGE() AS MensajeError;
END CATCH;
GO




---EJERCICIO 7: CONSULTA ANALÍTICA (ESQUEMA ESTRELLA)
USE NexoShop_S14;
GO

SELECT 
    c.Ciudad,
    p.Categoria,
    COUNT(*) AS CantidadOperaciones,
    SUM(f.Importe) AS TotalImporte
FROM dbo.FactVenta f
INNER JOIN dbo.Cliente c ON f.ClienteID = c.ClienteID
INNER JOIN dbo.Producto p ON f.ProductoID = p.ProductoID
GROUP BY c.Ciudad, p.Categoria
ORDER BY TotalImporte DESC;
GO




---EJERCICIO 8: RETO DE CONCURRENCIA (DOS CLIENTES POR EL ÚLTIMO PRODUCTO)

USE NexoShop_S14;
GO

-- 1. Preparar el escenario: dejar exactamente 1 unidad en stock del teclado (ProductoID = 101)
UPDATE dbo.Producto
SET Stock = 1
WHERE ProductoID = 101;

SELECT ProductoID, Nombre, Stock 
FROM dbo.Producto 
WHERE ProductoID = 101;
GO

-- 2. Simulación de llegada concurrente (Cliente 1 y Cliente 3 intentan comprar el último teclado)
DECLARE @PedidoCliente1 INT;
DECLARE @PedidoCliente3 INT;

-- Primer cliente en confirmar la transacción (gana el bloqueo exclusivo sobre la fila)
BEGIN TRY
    EXEC dbo.usp_CheckoutSeguro
        @ClienteID = 1,
        @ProductoID = 101,
        @Cantidad = 1,
        @CanalID = 1,
        @FechaKey = 20261115,
        @SimularFallo = 0,
        @PedidoNuevo = @PedidoCliente1 OUTPUT;

    SELECT 'Compra EXITOSA para Cliente 1' AS Resultado, @PedidoCliente1 AS PedidoID;
END TRY
BEGIN CATCH
    SELECT 'Compra RECHAZADA para Cliente 1' AS Resultado, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- Segundo cliente intenta comprar el mismo producto inmediatamente después
BEGIN TRY
    EXEC dbo.usp_CheckoutSeguro
        @ClienteID = 3,
        @ProductoID = 101,
        @Cantidad = 1,
        @CanalID = 2,
        @FechaKey = 20261115,
        @SimularFallo = 0,
        @PedidoNuevo = @PedidoCliente3 OUTPUT;

    SELECT 'Compra EXITOSA para Cliente 3' AS Resultado, @PedidoCliente3 AS PedidoID;
END TRY
BEGIN CATCH
    SELECT 'Compra RECHAZADA para Cliente 3' AS Resultado, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- 3. Verificación final de integridad: Stock en 0 (nunca negativo) y solo 1 pedido/pago nuevo
SELECT ProductoID, Nombre, Stock FROM dbo.Producto WHERE ProductoID = 101;
SELECT * FROM dbo.Pedido ORDER BY PedidoID DESC;
SELECT * FROM dbo.Pago ORDER BY PagoID DESC;
SELECT * FROM dbo.FactVenta ORDER BY VentaKey DESC;
GO




---EJERCICIO 9: DATOS DE PRUEBA PARA DASHBOARD POWER BI
USE NexoShop_S14;
GO

DECLARE @ID INT;

-- 1. Compra exitosa en Trujillo (Cliente 4) de Monitor 24 (103) por Aplicación (Canal 2)
EXEC dbo.usp_CheckoutSeguro @ClienteID = 4, @ProductoID = 103, @Cantidad = 1, @CanalID = 2, @FechaKey = 20261115, @SimularFallo = 0, @PedidoNuevo = @ID OUTPUT;

-- 2. Compra exitosa en Lima (Cliente 3) de Mouse óptico (102) por Web (Canal 1)
EXEC dbo.usp_CheckoutSeguro @ClienteID = 3, @ProductoID = 102, @Cantidad = 2, @CanalID = 1, @FechaKey = 20261115, @SimularFallo = 0, @PedidoNuevo = @ID OUTPUT;

-- 3. Compra fallida simulada por monto alto (Monitor 24) -> NO debe aparecer en Power BI
BEGIN TRY
    EXEC dbo.usp_CheckoutSeguro @ClienteID = 1, @ProductoID = 103, @Cantidad = 1, @CanalID = 1, @FechaKey = 20261115, @SimularFallo = 1, @PedidoNuevo = @ID OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'Operación revertida correctamente: no sumará en Power BI.';
END CATCH;
GO