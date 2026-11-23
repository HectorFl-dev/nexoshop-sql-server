# NexoShop — Modelo Transaccional, Concurrencia y BI en SQL Server

Implementación de una base de datos híbrida (**OLTP + Modelo Estrella**) para la gestión de comercio electrónico, control de inventario, manejo de concurrencia y explotación analítica en **Microsoft SQL Server (T-SQL)** y **Power BI**.

## Características principales
- **Arquitectura Híbrida (OLTP + Dimensional):**
  - **Tablas operativas:** `Cliente`, `Producto`, `Pedido`, `DetallePedido` y `Pago` con integridad referencial y restricciones `CHECK` para stock no negativo.
  - **Modelo Estrella (BI):** Tabla de hechos `FactVenta` conectada a `DimFecha`, `DimCanal`, `Cliente` y `Producto`.
- **Procedimientos Almacenados y Control Transaccional:**
  - `usp_ProductosDisponibles` y `usp_ProductosPorCategoria`: consultas parametrizadas de catálogo.
  - `usp_TotalPedidosCliente`: cálculo de métricas mediante parámetros `OUTPUT`.
  - `usp_PedidoBasico` y `usp_CheckoutSeguro`: checkout atómico con `BEGIN TRY...CATCH`, `SET XACT_ABORT ON` y `ROLLBACK TRANSACTION`.
- **Pruebas Incluidas:**
  - Simulación de fallos de pago con reversión total (`@SimularFallo = 1`).
  - Control de concurrencia cuando dos clientes compiten por la última unidad en stock.
  - Consultas analíticas agregadas por ciudad y categoría y carga de datos para dashboard.

## Contenido del repositorio
- `Codigo_SQL_nexo_Shop_14.sql`: Script completo ejecutable (creación de BD, tablas, carga inicial, procedimientos almacenados, pruebas de integridad, concurrencia y datos BI).
- `nexoShop_14.pbix` *(opcional)*: Reporte conectado al esquema dimensional en Power BI Desktop.

## Cómo ejecutar
1. Abrir **SQL Server Management Studio (SSMS)** (SQL Server 2016 SP1 o superior).
2. Abrir y ejecutar `Codigo_SQL_nexo_Shop_14.sql` de principio a fin.