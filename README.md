# Lua Taskpools
```
local yield = coroutine.yield

local TaskPool = require 'taskpool'
local pool = TaskPool.New()

pool:spawn(function ()
    for _ = 1, 10 do 
	    print('Hello from the side task!')
		yield()
    end
end)

local function lazy_map(xs, f)
    local result = {}
    for idx, x in pairs(xs) do
       result[idx] = f(x)
       yield(x)
    end
    return result
end

local handle = pool:spawn(lazy_map, {2,4,6,8,10}, function (x) return x * x end)

repeat
    local x = pool:query(handle) --- query returns the last yielded value until the coroutine reaches its final return
    print(x)
    pool:run()
until pool.alive_tasks == 0

-------------------------------

local results = pool:reap()
local xs = results[handle]

io.write('result = ') 
for k, v in pairs(xs) do
    io.write(tostring(v) .. ' ')
end
io.write('\n')
```
