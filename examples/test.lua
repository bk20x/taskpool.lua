local yield = coroutine.yield

local TaskPool = require 'taskpool'
local pool = TaskPool.New()

pool:spawn(function ()
    for _ = 1, 10 do
        print('Hello from task 1!')
        yield()
    end
end)

local task_id = pool:spawn(function ()
    local x = 1
    for _ = 1, 10 do
        x = x * 2
        print('Hello from task 2! x = ' .. tostring(x))
        yield()
    end
    return x
end)


repeat
    pool:run()
until pool.alive_tasks == 0


local result = pool:query(task_id)
print('result of task 2 = ' .. tostring(result))
