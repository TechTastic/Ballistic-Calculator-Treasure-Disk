---
--- Original creator of formulas: @malexy on Discord
--- Original creator of python functions: @sashafiesta on Discord
--- Optimized and translated python code to lua: SpaceEye. (https://gist.github.com/SuperSpaceEye/c33443213605d1bf35f81737c9058dc2)
--- Some lua optimizations: Autist69420
---

-- Simple micro-optimizations for better performance
local table_insert = table.insert
local rad, sin, cos, log, abs, min, pow = math.rad, math.sin, math.cos, math.log, math.abs, math.min, math.pow
local tu = table.unpack

local function linspace(start, end_, num)
    local linspaced = {}
    if num == 0 then return linspaced end
    if num == 1 then
        table_insert(linspaced, start)
        return linspaced
    end

    local delta = (end_ - start) / (num - 1)

    for i = 0, num-2 do
        table_insert(linspaced, start+delta*i)
    end
    table_insert(linspaced, end_)

    return linspaced
end

local function range(start, stop, step)
    step = step or 1
    local pos = start
    return function ()
        if step > 0 then
            if pos >= stop then return nil end
        else
            if pos <= stop then return nil end
        end
        local lpos = pos
        pos = pos + step
        return lpos
        end
end

local function flinspace(start, stop, num_elements, min, max)
    local items = {}
    for k, item in pairs(linspace(start, stop, num_elements)) do
        if not (item < min or item > max) then
            table.insert(items, item)
        end
    end
    local pos = 0
    return function() -- simple iterator
        pos = pos + 1
        return items[pos]
    end
end

local function get_root(d, from_end)
    if from_end then
        for i = #d-1, 1, -1 do
            if d[i][1] > d[i+1][1] then return d[i+1] end
        end
        return d[1]
    else
        for i = 2, #d, 1 do
            if d[i-1][1] < d[i][1] then return d[i-1] end
        end
        return d[#d]
    end
end

local function time_in_air(y0, y, Vy, gravity, max_steps)
    local t = 0
    local t_below = 9999999

    gravity = gravity or 0.05
    max_steps = max_steps or 1000000

    if y0 <= y then
        local y0p
        while t < max_steps/2 do
            y0p = y0
            y0 = y0 + Vy
            Vy = 0.99 * Vy - gravity
            t = t + 1

            if y0 > y then
                t_below = t-1
                break
            end

            if y0 - y0p < 0 then
                return -1, -1
            end
        end
    end

    while t < max_steps/2 do
        y0 = y0 + Vy
        Vy = 0.99 * Vy - gravity
        t = t + 1

        if y0 <= y then return t_below, t end
    end

    return t_below, -1
end

local function get_min(array)
    local min_delta_t = array[1][1]
    local pitch_ = 0;
    local airtime_ = 0;
    for i = 1, #array do
        if min_delta_t > array[i][1] then
            min_delta_t  = array[i][1]
            pitch_ = array[i][2]
            airtime_ = array[i][3]
        end
    end
    return min_delta_t, pitch_, airtime_
end

local function try_pitch(tried_pitch, initial_speed,
                         length, distance, cannon, target, delta_t_max_overshoot, gravity, max_steps)
    delta_t_max_overshoot = delta_t_max_overshoot or 1
    gravity = gravity or 0.05
    max_steps = max_steps or 1000000

    local tp_rad = rad(tried_pitch)

    local Vw = cos(tp_rad) * initial_speed
    local Vy = sin(tp_rad) * initial_speed

    local x_coord_2d = length * cos(tp_rad)

    if Vw == 0 then return nil, false end
    local part = 1 - (distance - x_coord_2d) / (100 * Vw)
    if part <= 0 then return nil, false end
    local horizontal_time_to_target = abs(log(part) / (-0.010050335853501))

    local y_coord_of_end_barrel = cannon[2] + sin(tp_rad) * length

    local t_below, t_above = time_in_air(y_coord_of_end_barrel, target[2], Vy, gravity, max_steps)

    if t_above < 0 then return nil, false end
    if t_above < horizontal_time_to_target - delta_t_max_overshoot then return nil, false end

    local delta_t = min(
            abs(horizontal_time_to_target - t_below),
            abs(horizontal_time_to_target - t_above)
    )

    return {delta_t, tried_pitch, delta_t + horizontal_time_to_target}, true
end

local function try_pitches(iter, ...)
    local delta_times = {}
    for pitch in iter do
        local items, is_successful = try_pitch(pitch, ...)
        if is_successful then table.insert(delta_times, items) end
    end
    return delta_times
end

-- Required parameters:
-- cannon = table of three numbers: x, y, z of cannon
-- target = same as cannon but for target
-- initial_speed = speed in m/s
-- length = length of a cannon
-- Optional parameters:
-- max_steps = maximum number of steps program will simulate projectile before declaring it unreachable
-- delta_t_max_overshoot = maximum difference between horizontal and vertical times to target before declaring target impossible to hit.
-- amin = minimum cannon angle
-- amax = maximum cannon angle
-- gravity = x m/tick
-- num_iterations = number of refining steps after roughly calculating angle
-- num_elements = number of elements to test during refining stage
-- check_impossible = does additional check for targets that are impossible to hit
local function calculate_pitch(cannon, target, initial_speed, length,
                               optional)
    local max_steps, delta_t_max_overshoot, amin, amax, gravity, num_iterations, num_elements, check_impossible
    optional = optional or {}
    max_steps = optional.max_steps or optional[1] or 100000
    delta_t_max_overshoot = optional.delta_t_max_overshoot or optional[2] or 1
    amin = optional.amin or optional[3] or -30
    amax = optional.amax or optional[4] or 60
    gravity = optional.gravity or optional[5] or 0.05
    num_iterations = optional.num_iterations or optional[6] or 5
    num_elements = optional.num_elements or optional[7] or 20
    check_impossible = optional.check_impossible or optional[8] or true

    local Dx, Dz = cannon[1] - target[1], cannon[3] - target[3]
    local distance = math.sqrt(Dx * Dx + Dz * Dz)

    local delta_times = try_pitches(range(amax, amin-1, -1),
            initial_speed, length, distance, cannon, target, delta_t_max_overshoot, gravity, max_steps)
    if #delta_times == 0 then return {{-1, -1, -1}, {-1, -1, -1}} end

    local dT1, p1, at1 = tu(get_root(delta_times, false))
    local dT2, p2, at2 = tu(get_root(delta_times, true))

    local c1 = true
    local c2 = not p1 == p2
    local same_res = p1 == p2

    local dTs1, dTs2

    for i in range(0, num_iterations) do
        if c1 then dTs1 = try_pitches(flinspace(p1-pow(10,-i), p1+pow(10,-i), num_elements, amin, amax), initial_speed, length, distance, cannon, target, delta_t_max_overshoot, gravity, max_steps) end
        if c2 then dTs2 = try_pitches(flinspace(p2-pow(10,-i), p2+pow(10,-i), num_elements, amin, amax), initial_speed, length, distance, cannon, target, delta_t_max_overshoot, gravity, max_steps) end

        if c1 and #dTs1 == 0 then c1=false end
        if c2 and #dTs2 == 0 then c2=false end

        if not c1 and not c2 then return {{-1, -1, -1}, {-1, -1, -1}} end

        if c1 then dT1, p1, at1 = get_min(dTs1) end
        if c2 then dT2, p2, at2 = get_min(dTs2) end
    end

    if same_res then dT2, p2, at2 = dT1, p1, at1 end

    local r1, r2 = {dT1, p1, at1}, {dT2, p2, at2}
    if check_impossible and dT1 > delta_t_max_overshoot then r1 = {-1, -1, -1} end
    if check_impossible and dT2 > delta_t_max_overshoot then r2 = {-1, -1, -1} end

    return r1, r2
end

local function calculate_yaw(Dx, Dz, direction)
    local yaw
    if Dx ~= 0 then
        yaw = math.atan(Dz/Dx) * 180/math.pi
    else
        yaw = 90
    end

    if Dx >= 0 then
        yaw = yaw + 180
    end

    local dirs = {90, 180, 270, 0}
    return (yaw + dirs[direction]) % 360
end

local function ballistics_to_target(cannon, target, power, direction, R1, R2, length)
    local directions = {north=1, west=2, south=3, east=4}
    direction = directions[direction]
    if direction == nil then error("Invalid direction") end

    local Dx, Dz = cannon[1] - target[1], cannon[3] - target[3]

    local r1, r2 = calculate_pitch(cannon, target, power, length)
    local yaw = calculate_yaw(Dx, Dz, direction)

    local rt = {}
    rt.yaw = yaw
    rt.yaw_time = yaw * 20 / (0.75 * R1)
    for k, v in pairs({[1]=r1, [2]=r2}) do
        local t = {pitch=-1, pitch_time=-1, airtime=-1, fuze_time=-1}
        if v[1] ~= -1 then
            t.delta_t = v[1]
            t.pitch = v[2]
            t.airtime = v[3]
            t.pitch_time = t.pitch * 20 / (0.75 * R2)
            t.precision = 1 - t.delta_t / t.airtime
        end
        table.insert(rt, k, t)
    end

    return rt
end

print("For the cannon coordinates, please input the coordinates of the cannon mount.")

cannonCoord = {}
print("x coord of cannon : ")
table_insert(cannonCoord, tonumber(io.read()))
print("y coord of cannon : ")
table_insert(cannonCoord, tonumber(io.read())+2)
print("z coord of cannon : ")
table_insert(cannonCoord, tonumber(io.read()))


targetCoord = {}
print("x coord of target : ")
table_insert(targetCoord, tonumber(io.read()))
print("y coord of target : ")
table_insert(targetCoord, tonumber(io.read()))
print("z coord of target : ")
table_insert(targetCoord, tonumber(io.read()))

print("Number of powder charges (int) : ")
powderCharges = tonumber(io.read())

print("What is the standart direction of the cannon ? (north, south, east, west)")
directionOfCannon = io.read()

print("What is the RPM of the yaw axis ?")
yawRPM = tonumber(io.read())
print("What is the RPM of the pitch axis ?")
pitchRPM = tonumber(io.read())

print("What is the length of the cannon ? (From the block held by the mount to the tip of the cannon, the held block excluded) ")
cannonLength = tonumber(io.read())

 --local cannonCoord = {100, 0, 100}
 --local targetCoord = {500, 0, 200}
 --local powderCharges = 8
 --local directionOfCannon = "north"
 --local yawRPM = 10
 --local pitchRPM = 10
 --local cannonLength = 32


 local rt = ballistics_to_target(
     cannonCoord,
     targetCoord,
     powderCharges,
     directionOfCannon,
     yawRPM,
     pitchRPM,
     cannonLength
 )

print("Yaw is ", rt.yaw)
print("With the yaw axis set at ", yawRPM, " rpm, the cannon must take ", rt.yaw_time, " ticks of turning the yaw axis.")

if rt[1].pitch ~= -1 then
    print("\nHigh shot:")
    print("Pitch is ", rt[1].pitch)
    print("Airtime is", rt[1].airtime, "ticks")
    print("With the pitch axis set at ", pitchRPM, " rpm, the cannon must take ", rt[1].pitch_time, " ticks of turning the pitch axis.")
    print("Precision: ", rt[1].precision)
else
    print("\nHigh shot is impossible")
end

if rt[2].pitch ~= -1 then
    print("\nLow shot:")
    print("Pitch is ", rt[2].pitch)
    print("Airtime is", rt[2].airtime, "ticks")
    print("With the pitch axis set at ", pitchRPM, " rpm, the cannon must take ", rt[2].pitch_time, " ticks of turning the pitch axis.")
    print("Precision: ", rt[2].precision)
else
    print("\nLow shot is impossible")
end
