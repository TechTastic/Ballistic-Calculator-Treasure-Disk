---
--- Original creator of formulas: @sashafiesta#1978 on Discord
--- Original creator of python functions: @Malex#6461 on Discord
--- Optimized and translated python code to lua: SpaceEye.
--- Optimised lua code: Autist69420
---

-- Simple micro-optimizations for better performance
local table_insert = table.insert
local math_rad, math_sin, math_cos, math_log, math_abs, math_min = math.rad, math.sin, math.cos, math.log, math.abs, math.min

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

local function time_in_air(y0, y, Vy)
    local t = 0
    local t_below = 9999999

    if y0 <= y then
        local y0p
        while t < 100000 do
            y0p = y0
            y0 = y0 + Vy
            Vy = 0.99 * Vy - 0.05
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

    while t < 100000 do
        y0 = y0 + Vy
        Vy = 0.99 * Vy - 0.05
        t = t + 1

        if y0 <= y then return t_below, t end
    end

    return t_below, -1
end

local function get_rough_min(array)
    local min_delta_t = array[1][1]
    local pitch = 0;
    for i = 1, #array do
        if min_delta_t > array[i][1] then
            min_delta_t = array[i][1]
            pitch = array[i][2]
        end
    end
    return min_delta_t, pitch
end

local function get_refined_min(array)
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

local function try_pitch(tried_pitch, initial_speed, cannon, length, target, distance)
    local tried_pitch_rad = math_rad(tried_pitch)
    local Vw = math_cos(tried_pitch_rad) * initial_speed
    local Vy = math_sin(tried_pitch_rad) * initial_speed
    local x_coord_2d = length * math_cos(tried_pitch_rad)

    if Vw == 0 then return "continue" end

    local part = 1 - (distance - x_coord_2d) / (100 * Vw)
    if part <= 0 then return "continue" end

    local time_to_target = math_abs(math_log(part) / (-0.010050335853501))
    local y_coord_of_end_barrel = cannon[2] + math_sin(tried_pitch_rad) * length
    local t_below, t_above = time_in_air(y_coord_of_end_barrel, target[2], Vy)

    if t_below == "error" then return "continue" end

    local delta_t = math_min(
            math_abs(time_to_target - t_below),
            math_abs(time_to_target - t_above)
    )

    return delta_t, delta_t + time_to_target
end

local function rough_estimation(tried_pitch, initial_speed, cannon, length, target, distance, delta_times)
    local delta_T, _ = try_pitch(tried_pitch, initial_speed, cannon, length, target, distance)

    if delta_T == "continue" then
        return
    end

    table_insert(delta_times, {delta_T, tried_pitch})
end

local function fine_estimation(tried_pitch, initial_speed, cannon, length, target, distance, delta_times)
    local delta_T, air_time = try_pitch(tried_pitch, initial_speed, cannon, length, target, distance)

    if delta_T == "continue" then
        return
    end

    table_insert(delta_times, { delta_T, tried_pitch, air_time })
end

local function ballistics_to_target(cannon, target, power, direction, R1, R2, length)
    local Dx, Dz = cannon[1] - target[1], cannon[3] - target[3]
    local distance = math.sqrt(Dx * Dx + Dz * Dz)
    local initial_speed = power
    local yaw = 0

    if Dx ~= 0 then
        yaw = math.atan(Dz / Dx) * 180 / math.pi
    else
        yaw = 90
    end

    if Dx >= 0 then yaw = yaw + 180 end

    local delta_times = {}

    for tried_pitch = 60, -31, -1 do rough_estimation(tried_pitch, initial_speed, cannon, length, target, distance, delta_times) end

    if #delta_times == 0 then return "unreachable" end

    local _, pitch = get_rough_min(delta_times)

    delta_times = {}
    local pitches = linspace(pitch-1, pitch+1, 20)
    for i = 1, 20 do fine_estimation(pitches[i], initial_speed, cannon, length, target, distance, delta_times) end

    if #delta_times == 0 then return "unreachable" end

    local delta_time, refined_pitch, airtime = get_refined_min(delta_times)

    if refined_pitch > 60 or refined_pitch < -30 then return "unreachable" end

    if direction == "north" then
        yaw = (yaw + 90) % 360
    elseif direction == "west" then
        yaw = (yaw + 180) % 360
    elseif direction == "south" then
        yaw = (yaw + 270) % 360
    elseif direction ~= "east" then
        return "invalid_direction", 0, 0, 0, 0, 0
    end

    local yawTime = yaw * 20 / (0.75 * R1)
    local pitchTime = refined_pitch * 20 / (0.75 * R2)
    local fuzeTime = airtime + (delta_time / 2.) - 10

    return yaw, refined_pitch, airtime, yawTime, pitchTime, fuzeTime
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

-- local cannonCoord = {100, 50, 100}
-- local targetCoord = {500, 200, 200}
-- local powderCharges = 8
-- local directionOfCannon = "north"
-- local yawRPM = 10
-- local pitchRPM = 10
-- local cannonLength = 32


 local yaw, pitch, airtime, yawTime, pitchTime, fuzeTime = ballistics_to_target(
     cannonCoord,
     targetCoord,
     powderCharges,
     directionOfCannon,
     yawRPM,
     pitchRPM,
     cannonLength
 )

if yaw ~= "unreachable" and yaw ~= "invalid_direction" then
    print("Yaw is ", yaw)
    print("Pitch is ", pitch)
    print("Airtime is", airtime, "ticks")
    print("With the yaw axis set at ", yawRPM, " rpm, the cannon must take ", yawTime, " ticks of turning the yaw axis.")
    print("With the pitch axis set at ", pitchRPM, " rpm, the cannon must take ", pitchTime, " ticks of turning the pitch axis.")
    print("You must set the fuze time to", fuzeTime , "ticks")
else
    print("Not valid")
end
