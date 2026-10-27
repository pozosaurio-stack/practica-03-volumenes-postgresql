# Guion para el audio de la Práctica N.º 3

Duración estimada: 75 a 90 segundos.

En esta práctica aprendí a diferenciar el ciclo de vida de un contenedor del ciclo de vida de sus datos. Al trabajar con PostgreSQL dentro de Docker comprendí que un contenedor puede eliminarse y crearse nuevamente a partir de la misma imagen, pero su capa de escritura anterior no se recupera de manera automática. Por eso, cuando la base de datos se guarda solamente en el almacenamiento asociado al contenedor y este no se reutiliza, la base, las tablas y los registros dejan de estar disponibles en el nuevo contenedor.

También aprendí a crear un volumen nombrado con Docker y a montarlo en el directorio de datos de PostgreSQL. El volumen tiene un ciclo de vida independiente, de modo que permanece aunque el contenedor sea detenido y eliminado. Al crear otro contenedor y conectar nuevamente el mismo volumen, PostgreSQL puede leer el clúster de datos existente y recuperar la base de datos, la tabla customer y los registros insertados.

Esta práctica me permitió entender que detener un contenedor, eliminar un contenedor y eliminar un volumen son operaciones diferentes. Además, reforcé el uso de comandos de Docker, la ejecución de instrucciones SQL con psql y la verificación de resultados mediante consultas. La persistencia es importante porque una base de datos debe conservar información ante despliegues, actualizaciones o fallos del contenedor. Como aprendizaje final, considero indispensable administrar los volúmenes con cuidado, realizar respaldos y evitar comandos de limpieza global que puedan borrar información de otros proyectos.

