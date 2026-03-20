local TaskPool = {}
TaskPool.__index = TaskPool

local next_id = (function ()
    local x = 0
    return function ()
        x = x + 1
        return x
    end
end)()

local function resume(task)
    if task.args then
        local coro_args = task.args
        task.args = nil
        return coroutine.resume(task.job, table.unpack(coro_args))
    else
        return coroutine.resume(task.job)
    end
end

local function try_task(task)
    if task.status == "dead" then
        return true, task.results
    end
    local success, results = resume(task)
    task.status  = coroutine.status(task.job)
    task.results = results
    if not success then
        print(string.format("Task reentry for id %d failed with: %s", task.id, results))
        return false, results
    else
        return true, results
    end
end


function TaskPool.New()
    local result = {
        tasks       = {},
        dead_tasks  = {},
        alive_tasks = 0
    }
    return setmetatable(result, TaskPool)
end


function TaskPool:despawn(handle)
    if self.tasks[handle] and not self.dead_tasks[handle] then
        self.alive_tasks = self.alive_tasks - 1
    end
    self.tasks[handle]      = nil
    self.dead_tasks[handle] = nil
end


--- Returns the last yielded value of the task or its final return value being `val` and its status being `stat` in `val, stat`
function TaskPool:query(handle)
    local task = self.tasks[handle]
    if not task then return nil else return task.results, task.status end
end


--- Immediately invokes `func` with trailing args and registers it as a task
function TaskPool:spawn(func, ...)
    local args = {...}
    local coro = coroutine.create(func)
    local id   = next_id()
    local task = {
        id      = id,
        job     = coro, -- lol job and task are basically the same word
        status  = nil,
        results = nil
    }
    local success, results = coroutine.resume(task.job, table.unpack(args))
    if not success then
        print(string.format("Failed to spawn taskno %d with: %s", task.id, results))
        return nil
    end
    task.status  = coroutine.status(task.job)
    task.results = results
    if task.status == "dead" then -- for tasks that may finish immediately, ie not yielding anything or yielding conditionally
        self.dead_tasks[id] = task
    else
        self.tasks[id]   = task
        self.alive_tasks = self.alive_tasks + 1
    end
    return id
end

--- Same as spawn only it does not immediately invoke `func` and waits for the next time run() is called or the task is awaited
function TaskPool:doLater(func, ...)
    local args = {...}
    local coro = coroutine.create(func)
    local id   = next_id()
    local task = {
        id      = id,
        job     = coro,
        status  = coroutine.status(coro),
        results = nil,
        args    = args --- we need to store them to pass to resume when they are eventually called for the first time. after that args is set to nil
    }
    self.tasks[id]    = task
    self.alive_tasks  = self.alive_tasks + 1
    return id
end

--- Iterates over all living tasks once invoking them
function TaskPool:run()
    for id, task in pairs(self.tasks) do
        if task.status ~= "dead" then
            local success, _ = try_task(task)
            if not success then
                self:despawn(id)
            end
        else
            if not self.dead_tasks[task.id] then -- dead tasks still hold their results to be awaited or reaped
                self.alive_tasks = self.alive_tasks - 1
                self.dead_tasks[task.id] = task
            end
        end
    end
end

--- Blocks until the task is completed and returns its result
function TaskPool:await(handle)
    local task = self.tasks[handle]
    if not task then return nil end
    while true do
        local success, results = try_task(task)
        if not success or task.status == "dead" then
            self:despawn(task.id)
            return results
        end
    end
end

--- Despawns all dead tasks and returns their results as a table of ids to their corresponding results
function TaskPool:reap()
    local result = {}
    for id, task in pairs(self.dead_tasks) do
        result[id] = task.results
        self:despawn(id)
    end
    return result
end


--- Despawns all dead tasks
function TaskPool:drain()
    for id, task in pairs(self.tasks) do
        if task.status == "dead" then
            self:despawn(id)
        end
    end
end


--- Despawns all tasks regardless of their status
function TaskPool:clear()
    for id, task in pairs(self.tasks) do
        self:despawn(id)
    end
end


--- Blocks until all tasks are finished. Does not despawn any tasks so their results are collectable with reap()
function TaskPool:awaitAll()
    while self.alive_tasks > 0 do
        self:run()
    end
end
return TaskPool
