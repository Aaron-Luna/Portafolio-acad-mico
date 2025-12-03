/*
==============================================
EQUIPO 10

Integrantes:
Hérnandez Mendoza Regina
Luna García Aarón Abdí
Orenda Rojas Jimena
Zúñiga Castillo Carolina 
=============================================
*/


-- Pregunta 1
-- ¿Qué clientes tienen un gasto total mayor al promedio de gasto de todos los clientes?

USE zapata;

SELECT c.cliente_id, CONCAT_WS(' ',c.nombre, c.apellido1, c.apellido2) AS cliente, e.nombre AS estado, m.nombre AS municipio, SUM(v.total) AS gasto_total
FROM clientes c JOIN direcciones d ON d.id_direccion = c.id_direccion JOIN colonias col ON col.id_colonia = d.id_colonia JOIN municipios m ON m.clave = col.clave_mun
JOIN estados e ON e.clave = m.clave_estado JOIN ventas v ON v.cliente_id = c.cliente_id GROUP BY c.cliente_id HAVING SUM(v.total) > (SELECT AVG(gasto_por_cliente)
FROM (SELECT v2.cliente_id, SUM(v2.total) AS gasto_por_cliente FROM ventas v2 GROUP BY v2.cliente_id) AS R) ORDER BY gasto_total DESC;


-- Pregunta 2
-- ¿Cuáles son los proveedores que presentan pedidos cancelados, qué porcentaje representan estos pedidos respecto al total que han realizado,
-- y cuál es la cantidad de productos involucrados en cancelaciones durante los últimos seis meses?

SELECT p.proveedor_id AS "ID Proveedor", p.nombre AS "Proveedor", COUNT(pe.pedido_id) AS "Total de pedidos", 
    SUM(CASE WHEN pe.estatus = 'Cancelado' THEN 1 ELSE 0 END) AS "Pedidos cancelados", CONCAT(ROUND((SUM(CASE WHEN pe.estatus = 'Cancelado' THEN 1 ELSE 0 END) * 100.0) / COUNT(pe.pedido_id),2),'%') AS "Porcentaje de pedidos cancelados",
    CASE WHEN SUM(CASE WHEN pe.estatus = 'Cancelado' AND DATEDIFF(CURDATE(), pe.fecha_pedido) <= 180 THEN dp.cantidad ELSE 0 END) IS NULL THEN 0 ELSE
    SUM(CASE WHEN pe.estatus = 'Cancelado' AND DATEDIFF(CURDATE(), pe.fecha_pedido) <= 180 THEN dp.cantidad ELSE 0 END) END AS "Cantidad involucrada" 
    FROM proveedores AS p INNER JOIN pedidos AS pe ON pe.proveedor_id = p.proveedor_id LEFT JOIN detalle_pedido AS dp ON dp.pedido_id = pe.pedido_id
    GROUP BY p.proveedor_id HAVING SUM(CASE WHEN pe.estatus = 'Cancelado' THEN 1 ELSE 0 END) > 0 ORDER BY 5;

-- Pregunta 3
-- ¿Qué vendedores han tenido el mejor desempeño (más ventas) durante el año por cada mes?

SELECT SUBSTR(Mes,1,3) AS 'Mes', Vendedor, Total_ventas FROM (SELECT MONTH(v.fecha),MONTHNAME(v.fecha) as Mes, v.vendedor_id,SUM(v.total) as Total_ventas, CONCAT_WS(' ', vd.nombre,vd.apellido1,vd.apellido2) as Vendedor
FROM ventas v JOIN vendedores vd USING(vendedor_id) WHERE YEAR(v.fecha) = 2025 GROUP BY 1,2,3 ORDER BY 1,4 DESC) AS f
WHERE Total_ventas IN(SELECT MAX(Total_ventas) FROM (SELECT MONTH(v.fecha) as Mes, v.vendedor_id,SUM(v.total) as Total_ventas
FROM ventas v JOIN vendedores vd USING(vendedor_id) WHERE YEAR(v.fecha) = 2025 GROUP BY 1,2) AS p GROUP BY Mes);

-- Pregunta 4
-- ¿Cuál es el porcentaje de clientes que ha comprado más de un par de zapatos?

SELECT (Clientes_par / T.total_clientes) * 100 as 'Porcentaje de clientes con compras mayores a 1 par'
FROM (SELECT COUNT(C.cliente_id) AS Clientes_par FROM (SELECT c.cliente_id, COUNT(v.venta_id) as total_compras FROM clientes c JOIN ventas v USING(cliente_id)
GROUP BY 1 HAVING total_compras > 1) AS C) AS TC1, (SELECT COUNT(DISTINCT cliente_id) as total_clientes FROM ventas) AS T;


-- Pregunta 5
-- ¿Cuáles son los productos que tienen muchas piezas en el inventario, pero que no se han vendido en los últimos 6 meses?

SELECT m.nombre AS Modelo, JSON_ARRAYAGG(JSON_OBJECT('Talla', t.talla, 'Color', c.nombre)) as 'Talla y color', SUM(inS.cantidad) as StockActual
FROM inventario_sucursales inS JOIN inventario i USING(inventario_id) JOIN modelos m USING(modelo_id) JOIN tallas t USING(talla_id) JOIN colores c USING(color_id)
WHERE inS.cantidad =(SELECT MAX(SA.StockActual) FROM( SELECT inS.cantidad AS StockActual FROM inventario_sucursales inS JOIN inventario i USING(inventario_id)
JOIN modelos m USING(modelo_id) JOIN tallas t USING(talla_id) JOIN colores c USING(color_id)) AS SA) AND i.inventario_id NOT IN (SELECT dv.inventario_id
FROM detalle_ventas dv JOIN ventas V USING(venta_id) WHERE DATEDIFF(CURDATE(), v.fecha) < 180 GROUP BY dv.inventario_id HAVING SUM(DV.cantidad) > 0)
GROUP BY m.nombre;

-- Pregunta 6
-- ¿Qué clientes han comprado en más de una sucursal?


SELECT c.cliente_id, CONCAT(c.nombre,' ',c.apellido1,' ',c.apellido2) AS cliente, COUNT(DISTINCT ven.sucursal_id) AS sucursales_distintas, GROUP_CONCAT(DISTINCT s.nombre ORDER BY s.sucursal_id SEPARATOR '; ') AS sucursales_nombres
FROM clientes c JOIN ventas v ON c.cliente_id = v.cliente_id JOIN vendedores ven ON v.vendedor_id = ven.vendedor_id JOIN sucursales s ON ven.sucursal_id = s.sucursal_id GROUP BY c.cliente_id HAVING sucursales_distintas > 1
ORDER BY sucursales_distintas DESC;


-- Pregunta 7 
-- ¿Qué clientes están en riesgo de abandono?


WITH historial AS (SELECT c.cliente_id, CONCAT(c.nombre,' ',c.apellido1) AS cliente, MAX(v.fecha) AS ultima_compra, DATEDIFF(CURDATE(), MAX(v.fecha)) AS dias_desde_ultima 
FROM clientes c LEFT JOIN ventas v ON c.cliente_id = v.cliente_id GROUP BY c.cliente_id) SELECT cliente_id, cliente, ultima_compra, dias_desde_ultima FROM historial
WHERE dias_desde_ultima > 90
ORDER BY dias_desde_ultima DESC;

-- Pregunta 8 
-- ¿Qué tallas presentan mayor riesgo de sobreinventario?


WITH ventas_por_talla AS (SELECT t.talla_id, t.talla AS talla, SUM(dv.cantidad) AS unidades_vendidas FROM detalle_ventas dv JOIN inventario inv ON dv.inventario_id = inv.inventario_id JOIN tallas t ON inv.talla_id = t.talla_id GROUP BY t.talla_id),
stock_por_talla AS (SELECT t.talla_id, SUM(isu.cantidad) AS stock_total FROM inventario_sucursales isu JOIN inventario inv ON isu.inventario_id = inv.inventario_id JOIN tallas t ON inv.talla_id = t.talla_id 
GROUP BY t.talla_id), ratio AS (SELECT s.talla_id, v.talla, v.unidades_vendidas, s.stock_total, CASE WHEN v.unidades_vendidas = 0 THEN NULL WHEN v.unidades_vendidas IS NULL THEN NULL ELSE ROUND(s.stock_total / v.unidades_vendidas, 2) END AS ratio_sobreinventario 
FROM stock_por_talla s LEFT JOIN ventas_por_talla v ON s.talla_id = v.talla_id) SELECT talla_id, talla, unidades_vendidas, stock_total, ratio_sobreinventario, CASE WHEN ratio_sobreinventario IS NULL THEN 'SIN DATOS' WHEN ratio_sobreinventario > 5 THEN 'ALTO RIESGO' ELSE 'BAJO RIESGO' END AS nivel_riesgo FROM ratio
ORDER BY ratio_sobreinventario DESC;


-- Pregunta 9
-- ¿Cuál es el top 5 de tallas, modelos y colores más vendidos de zapatos?


SELECT * FROM (SELECT "Modelo" AS "Categoría", modelo_id AS "Identificador", nombre AS "Nombre", SUM(cantidad) AS "Ventas", 
CONCAT(ROUND(SUM(cantidad)/(SELECT SUM(cantidad) FROM detalle_ventas)*100,2), "%") AS "Porcentaje" 
FROM detalle_ventas AS d INNER JOIN inventario AS i USING(inventario_id) INNER JOIN modelos as m USING(modelo_id) 
GROUP BY modelo_id ORDER BY 5 DESC LIMIT 5) AS Top_Modelos

UNION ALL

SELECT "" AS "Categoría", "" AS "Identificador", "" AS "Nombre", "" AS "Ventas", "" AS "Porcentaje"

UNION ALL

SELECT * FROM (SELECT "Talla" AS "Categoría", talla_id AS "Identificador", talla AS "Nombre", SUM(cantidad) AS "Ventas", CONCAT(ROUND(SUM(cantidad)/(SELECT SUM(cantidad) 
FROM detalle_ventas)*100,2), "%") AS "Porcentaje" FROM detalle_ventas AS d INNER JOIN inventario AS i USING(inventario_id) INNER JOIN tallas as t USING(talla_id) 
GROUP BY talla_id ORDER BY 5 DESC LIMIT 5) AS Top_Tallas

UNION ALL

SELECT "" AS "Categoría", "" AS "Identificador", "" AS "Nombre", "" AS "Ventas", "" AS "Porcentaje"

UNION ALL

SELECT * FROM (SELECT "Color" AS "Categoría", color_id AS "Identificador", nombre AS "Nombre", SUM(cantidad) AS "Ventas", 
CONCAT(ROUND(SUM(cantidad)/(SELECT SUM(cantidad) FROM detalle_ventas)*100,2), "%") AS "Porcentaje" 
FROM detalle_ventas AS d INNER JOIN inventario AS i USING(inventario_id) INNER JOIN colores as c USING(color_id) GROUP BY color_id ORDER BY 5 DESC LIMIT 5) AS Top_Colores;


-- Pregunta 10
-- ¿Cuáles son los modelos que otorgan el mayor y menor margen de beneficio respecto a sus precios de compra-venta, así como sus porcentajes dentro de las ventas?

-- MAYOR:

SELECT m.modelo_id AS "Identificador modelo", m.nombre AS "Nombre modelo", d.precio_compra AS "Precio de compra", m.precio_venta AS "Precio de venta", 
((m.precio_venta-d.precio_compra)/ d.precio_compra) * 100 AS "Margen de utilidad", v.Porcentaje AS "Porcentaje ventas" 
FROM detalle_pedido AS d INNER JOIN inventario_sucursales as s USING(id_inv_suc) INNER JOIN inventario AS i USING(inventario_id) INNER JOIN modelos as m USING(modelo_id) 
INNER JOIN (SELECT modelo_id AS Modelo, SUM(cantidad) AS Acumulado, CONCAT(ROUND(SUM(cantidad)/(SELECT SUM(cantidad) FROM detalle_ventas) * 100,2), "%") AS Porcentaje 
FROM detalle_ventas AS d INNER JOIN inventario AS i USING(inventario_id) INNER JOIN modelos as m USING(modelo_id) GROUP BY modelo_id) AS v ON v.Modelo = m.modelo_id ORDER BY 5 DESC LIMIT 10;

-- MENOR: 

SELECT m.modelo_id AS "Identificador modelo", m.nombre AS "Nombre modelo", d.precio_compra AS "Precio de compra", m.precio_venta AS "Precio de venta",
((m.precio_venta-d.precio_compra)/ d.precio_compra) * 100 AS "Margen de utilidad", v.Porcentaje AS "Porcentaje ventas" FROM detalle_pedido AS d 
INNER JOIN inventario_sucursales as s USING(id_inv_suc) INNER JOIN inventario AS i USING(inventario_id) INNER JOIN modelos as m USING(modelo_id) 
INNER JOIN (SELECT modelo_id AS Modelo, SUM(cantidad) AS Acumulado, CONCAT(ROUND(SUM(cantidad)/(SELECT SUM(cantidad) FROM detalle_ventas) * 100,2), "%") AS Porcentaje 
FROM detalle_ventas AS d INNER JOIN inventario AS i USING(inventario_id) INNER JOIN modelos as m USING(modelo_id) GROUP BY modelo_id) AS v ON v.Modelo = m.modelo_id ORDER BY 5 LIMIT 10;


-- Pregunta 11
-- ¿Qué porcentaje de clientes reside en cada alcaldía (considerando únicamente la CDMX)? Caso donde se toma en cuenta las alcaldías donde se cuenta con sucursales así como el caso donde no.

-- CASO DONDE SI:

SELECT m.clave AS "Clave de la alcaldía", m.nombre AS "Alcaldía", COUNT(c.cliente_id) AS "Número de clientes", 
CONCAT(ROUND(COUNT(c.cliente_id)/(SELECT COUNT(*) FROM clientes as c INNER JOIN direcciones AS d USING(id_direccion) 
INNER JOIN colonias AS l USING(id_colonia) INNER JOIN municipios AS m ON m.clave = l.clave_mun INNER JOIN estados as e ON e.clave = m.clave_estado WHERE e.clave = "09"), 2), "%") AS "Porcentaje de los clientes que viven en CDMX" 
FROM clientes AS c INNER JOIN direcciones AS d USING(id_direccion) INNER JOIN colonias AS l USING(id_colonia) INNER JOIN municipios AS m ON m.clave = l.clave_mun GROUP BY m.clave ORDER BY 4 DESC;

-- CASO DONDE NO:

SELECT m.clave AS "Clave de la alcaldía", m.nombre AS "Alcaldía", COUNT(c.cliente_id) AS "Número de clientes", 
CONCAT(ROUND(COUNT(c.cliente_id)/(SELECT COUNT(*) FROM clientes as c INNER JOIN direcciones AS d USING(id_direccion) INNER JOIN colonias AS l USING(id_colonia) 
INNER JOIN municipios AS m ON m.clave = l.clave_mun INNER JOIN estados as e ON e.clave = m.clave_estado WHERE e.clave = "09" AND m.clave NOT IN(09010,09017)), 2), "%") AS "Porcentaje de los clientes que viven en CDMX" 
FROM clientes AS c INNER JOIN direcciones AS d USING(id_direccion) INNER JOIN colonias AS l USING(id_colonia) INNER JOIN municipios AS m ON m.clave = l.clave_mun INNER JOIN estados as e ON e.clave = m.clave_estado 
WHERE m.clave NOT IN(09010,09017) GROUP BY m.clave ORDER BY 4 DESC;


-- AUTOMATIZACIÓN

-- TRIGGER:
/*
Actualización de inventario cuando se llega un pedido
Este trigger (TR_ActualizarInventario) se activa inmediatamente después de la actualización del estatus de los pedidos que estaban pendientes. 
Su función es aumentar la cantidad (NEW.cantidad) en el stock  disponible en la tabla inventario_sucursales con la cantidad recibida del pedido, 
asegurando que la actualización se aplique en id_inv_suc correspondiente al pedido_id que cambió de estatus.
*/

-- Creación de tabla donde se registran los cambios realizados en el inventario de la sucursal
DROP TABLE IF EXISTS log_cambiosInventario;
CREATE TABLE log_cambiosInventario (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    tabla_afectada VARCHAR(30),
    id_registro INT,
    fecha_evento DATETIME,
    descripcion_cambio VARCHAR(255),
    usuario_bd VARCHAR(100)
);

-- Creacion de trigger para guardar en la tabla anterior los cambios cada que se actualice el inventario
DROP TRIGGER IF EXISTS TR_cambiosInventario;
DELIMITER $$
CREATE TRIGGER TR_cambiosInventario
AFTER UPDATE ON inventario_sucursales
FOR EACH ROW
BEGIN
        INSERT INTO log_cambiosInventario (
            tabla_afectada,
            id_registro,
            fecha_evento,
            descripcion_cambio,
            usuario_bd
        )
        VALUES (
            'inventario_sucursales',
            OLD.id_inv_suc, 
            NOW(),
            CONCAT(
                'Inventario actualizado. Cantidad cambió de', 
                OLD.cantidad, 
                ' a ', 
                NEW.cantidad,
                ' en sucursal ',
                OLD.sucursal_id
            ),
            USER());
END $$
DELIMITER ;

-- Trigger que actualiza el inventario de la sucursal conforme llegan los pedidos realizados
DROP TRIGGER IF EXISTS TR_ActualizarInventario;
DELIMITER //
CREATE TRIGGER TR_ActualizarInventario
AFTER UPDATE ON pedidos
FOR EACH ROW
BEGIN       
    IF OLD.estatus = 'Pendiente' AND NEW.estatus = 'Confirmado'
    THEN 
        UPDATE inventario_sucursales AS i
        INNER JOIN detalle_pedido AS dp
            USING(id_inv_suc)
        SET i.cantidad = i.cantidad + dp.cantidad
        WHERE dp.pedido_id = NEW.pedido_id;
    END IF;
END//
DELIMITER ;

-- Ejemplo
-- Consulta sobre el pedido que cambiará de estatus
SELECT fecha_pedido,id_inv_suc,pedido_id,dv.cantidad as cantidad_pedida,estatus,inS.cantidad
FROM pedidos p JOIN detalle_pedido dv USING(pedido_id) JOIN inventario_sucursales inS 
USING(id_inv_suc) WHERE pedido_id = 10;
-- Se actualiza el estatus del pedido que estaba Pendiente como Confirmado
UPDATE pedidos SET estatus = 'Confirmado' WHERE pedido_id = 10;
-- Consulta del inventario con la cantidad actualizada
SELECT fecha_pedido,id_inv_suc,pedido_id,dv.cantidad as cantidad_pedida,estatus,inS.cantidad
FROM pedidos p JOIN detalle_pedido dv USING(pedido_id) JOIN inventario_sucursales inS 
USING(id_inv_suc) WHERE pedido_id = 10;
-- Se confirma con la tabla los cambios
SELECT * from log_cambiosInventario;


-- PROCEDIMIENTO:
/*
 Ver en que sucursal hay zapatos disponibles de cierto modelo, color y talla

Este procedimiento permite a vendedores brindar de forma rápida certeza sobre el inventario en las sucursales de cierto producto a clientes interesados, 
ya sea en una combinación específica de modelo, color y talla, o simplemente quieran conocer la disponibilidad de cierto modelo en distintos colores y tallas.
*/

DROP PROCEDURE IF EXISTS buscar_zapato;

DELIMITER $$
CREATE PROCEDURE buscar_zapato(IN modelo VARCHAR(40), IN color VARCHAR(20), IN talla VARCHAR(4))
begin
SELECT m.nombre AS "Modelo", c.nombre AS "Color", t.talla AS "Talla", s.cantidad AS "Cantidad disponible", u.nombre AS "Sucursal" FROM inventario AS i INNER JOIN inventario_sucursales AS s USING(inventario_id) INNER JOIN (modelos AS m, tallas AS t, colores AS c, sucursales AS u) USING(modelo_id, talla_id, color_id, sucursal_id) WHERE m.nombre LIKE CONCAT("%", modelo, "%") AND c.nombre LIKE CONCAT("%", color, "%") AND t.talla LIKE CONCAT("%",talla,"%") ORDER BY 1,2,3;
end;
$$
DELIMITER ;

-- EJEMPLO
-- Supongamos que un cliente está interesado en conocer los distintos colores y tallas de los que se tiene disponibilidad del modelo “Zenit Tenis”, 
-- entonces mediante la siguiente consulta el empleado podrá brindar esa información:

call buscar_zapato("Zenit Tenis", "", "");


-- FUNCIÓN:
/*
 Se creará una función llamada “DIRECCION_CLIENTE”, la cual recibe como parámetro el id de algún cliente, y nos devuelve la dirección completa de este, 
 empezando desde la calle hasta el estado donde vive el cliente, esta función nos puede ayudar cuando se tenga que hacer un envio a este cliente, 
 pues nos permite obtener la información de envío de manera inmediata y sin necesidad de consultar múltiples tablas cada vez que se requiera mandar un pedido 
 o verificar la ubicación del cliente.
*/

DROP FUNCTION IF EXISTS DIRECCION_CLIENTE;

DELIMITER $$
CREATE FUNCTION DIRECCION_CLIENTE(id_cli INT)
RETURNS VARCHAR(400)
DETERMINISTIC
BEGIN
DECLARE resultado VARCHAR(400);
SELECT CONCAT_WS(', ', CONCAT_WS(' ', d.calle, d.num_ext, IF(d.num_int IS NULL OR d.num_int = '', NULL, CONCAT('Int.', d.num_int))), c.nombre, 
CONCAT('CP', ' ', c.cp), m.nombre, e.nombre) INTO resultado
FROM clientes cli JOIN direcciones d ON d.id_direccion = cli.id_direccion JOIN colonias c ON c.id_colonia = d.id_colonia JOIN municipios m ON m.clave = c.clave_mun
JOIN estados e ON e.clave = m.clave_estado WHERE cli.cliente_id = id_cli;
RETURN resultado;
END;
$$
DELIMITER ;

-- EJEMPLO: Obtener la dirección completa del cliente con ID = 1

SELECT DIRECCION_CLIENTE(1);


-- VISTA:
/*
Se creará una vista para generar un resumen estadístico por producto, ideal para analizar el comportamiento de ventas; incluye: total de unidades vendidas, 
número de ventas donde apareció el producto, primera fecha en que se vendió, última fecha en que se vendió, promedio de piezas por venta y categoría
Esta vista sirve para identificar: productos con alta demanda, detectar productos estacionarios, detectar productos estacionarios, medir la frecuencia y 
recurrencia de ventas, identificar productos extintos o populares.
*/

DELIMITER $$
CREATE OR REPLACE VIEW estadisticas_ventas_producto AS SELECT i.inventario_id, m.nombre AS modelo, c.nombre AS color, t.talla, 
IFNULL(SUM(dv.cantidad), 0) AS total_piezas_vendidas, COUNT(DISTINCT dv.venta_id) AS numero_de_ventas, 
CASE WHEN COUNT(DISTINCT dv.venta_id) = 0 THEN 0 ELSE SUM(dv.cantidad) / COUNT(DISTINCT dv.venta_id) END AS promedio_piezas_por_venta, MIN(v.fecha) AS primera_venta, 
MAX(v.fecha) AS ultima_venta FROM inventario i LEFT JOIN modelos m USING(modelo_id) LEFT JOIN colores c USING(color_id) LEFT JOIN tallas t USING(talla_id) 
LEFT JOIN detalle_ventas dv USING(inventario_id) LEFT JOIN ventas v USING(venta_id) GROUP BY i.inventario_id;
$$
DELIMITER ;

-- Ejemplo
-- Productos más vendidos
SELECT * FROM estadisticas_ventas_producto ORDER BY total_piezas_vendidas DESC LIMIT 10;

