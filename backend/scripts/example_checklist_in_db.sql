-- Ejemplo: checklist en columna jsonb `tasks.subtasks`
-- Formato que espera la API y el cliente Flutter tras normalización:
-- [{"id":1,"title":"Paso uno","isDone":false,"is_done":false}, ...]
--
-- Ver datos actuales:
--   SELECT id, title, jsonb_pretty(subtasks) FROM tasks WHERE id = <ID>;
--
-- Asignar checklist de prueba a una tarea existente (ajusta id y project_id):
/*
UPDATE tasks
SET subtasks = '[
  {"id":1,"title":"Hecho en SQL 1","isDone":true,"is_done":true},
  {"id":2,"title":"Pendiente SQL 2","isDone":false,"is_done":false}
]'::jsonb,
    updated_at = now()
WHERE id = 1;
*/
