--[[
====================================================================
   NULL HUB  -  BLACK SCYTHE TRANSFORMATION  (v1.0)
====================================================================
   * 20 skill + Nút Biến Hình + Đánh Thường + Chiêu Cuối
   * Toàn bộ hiệu ứng tông trắng - đen
   * Lưỡi hái đen cầm tay, tư thế ngầu, toàn thân hóa đen khi biến hình
   * Có phân thân, triệu hồi, niệm chú, múa kiếm...
   * KHÔNG dùng Explosion (đã thay bằng Black Hole / Pillar)
   * Hỗ trợ ĐIỆN THOẠI + PC, GUI kéo qua kéo lại được
   * Title "null hub" màu đỏ glitch rò rỉ
--------------------------------------------------------------------
   CÁCH DÙNG:
   - Script thường: bỏ vào StarterPlayer > StarterPlayerScripts (LocalScript)
   - Dùng executor (Delta/Fluxus/Hydrogen...): paste & chạy trực tiếp
   - Lưu ý: gây damage thật trong game chính thức cần RemoteEvent của
     game đó; script này gây damage local + hiệu ứng full. Để gây
     damage server, thay hàm damageNearby() bằng fire remote của game.
====================================================================
]]

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UserInput     = game:GetService("UserInputService")
local Workspace     = game:GetService("Workspace")
local Lighting      = game:GetService("Lighting")

local player    = Players.LocalPlayer
local camera    = Workspace.CurrentCamera
local mouse     = player:GetMouse()

-- trạng thái toàn cục
local transformed   = false
local scytheModel   = nil
local flying        = false
local flyConn       = nil
local shieldActive  = false
local shieldPart    = nil
local clones        = {}
local timeSlowConn  = nil
local reaperRingConn= nil

-- màu chủ đạo (trắng - đen)
local C_BLACK   = Color3.fromRGB(0,0,0)
local C_WHITE   = Color3.fromRGB(255,255,255)
local C_GRAY    = Color3.fromRGB(80,80,80)
local C_DARKGRAY= Color3.fromRGB(25,25,25)
local C_RED     = Color3.fromRGB(255,0,0)

-- ==================================================================
--   HÀM TIỆN ÍCH
-- ==================================================================
local function tween(obj, props, time, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.5, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function char()
    return player.Character or player.CharacterAdded:Wait()
end

local function root()
    local c = char()
    return c:FindFirstChild("HumanoidRootPart"), c:FindFirstChild("Humanoid")
end

-- gây damage cho mọi người trong bán kính (local)
local function damageNearby(pos, radius, dmg, ignoreSelf)
    ignoreSelf = ignoreSelf ~= false
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Health > 0 then
            local p = v.Parent
            if p and p:FindFirstChild("HumanoidRootPart") then
                local skip = ignoreSelf and p == char()
                if not skip then
                    local dist = (p.HumanoidRootPart.Position - pos).Magnitude
                    if dist <= radius then
                        pcall(function() v:TakeDamage(dmg) end)
                        pcall(function() v.Health = v.Health - dmg end)
                    end
                end
            end
        end
    end
end

-- tạo part hiệu ứng nhanh
local function fxPart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Material = Enum.Material.Neon
    p.Color = C_WHITE
    p.Size = Vector3.new(1,1,1)
    for k, v in pairs(props or {}) do p[k] = v end
    p.Parent = Workspace
    return p
end

local function fadeDestroy(p, time)
    tween(p, {Transparency = 1, Size = p.Size * 1.5}, time or 0.4)
    task.delay(time or 0.4, function() if p then p:Destroy() end end)
end

-- ==================================================================
--   TẠO GUI  (null hub - đỏ glitch, kéo được)
-- ==================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "NullHubGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not ok then gui.Parent = player:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 310, 0, 460)
main.Position = UDim2.new(0, 15, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(8,8,10)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true   -- KÉO QUA KÉO LẠI ĐƯỢC
main.ClipsDescendants = true
main.Parent = gui

-- viền trắng
local border = Instance.new("UIStroke")
border.Color = C_WHITE
border.Thickness = 1.5
border.Transparency = 0.3
border.Parent = main

-- thanh tiêu đề
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,38)
titleBar.BackgroundColor3 = C_BLACK
titleBar.BorderSizePixel = 0
titleBar.Parent = main

-- 2 lớp chữ "null hub" để tạo hiệu ứng glitch rò rỉ (đỏ + trắng)
local function makeTitle(color, zindex, offset)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,0,1,0)
    t.BackgroundTransparency = 1
    t.Text = "null hub"
    t.Font = Enum.Font.Code
    t.TextSize = 22
    t.TextColor3 = color
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = zindex
    t.Parent = titleBar
    return t
end
local titleRed   = makeTitle(C_RED, 2, 0)
local titleWhite = makeTitle(C_WHITE, 3, 0)
titleRed.Position = UDim2.new(0,12,0,0)
titleWhite.Position = UDim2.new(0,12,0,0)

-- hiệu ứng glitch: dịch chệch + nhấp nháy liên tục
task.spawn(function()
    while gui.Parent do
        local ox = math.random(-3,3)
        local oy = math.random(-2,2)
        titleRed.Position = UDim2.new(0, 12 + ox, 0, oy)
        titleWhite.Position = UDim2.new(0, 12 - ox, 0, -oy)
        titleRed.TextTransparency = math.random(0,6)/10
        if math.random(1,5) == 1 then
            titleWhite.Text = "nu" .. string.rep("l", math.random(1,3)) .. " hub"
        else
            titleWhite.Text = "null hub"
        end
        task.wait(math.random(1,6)/100)
    end
end)

-- nút thu gọn
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0,30,0,30)
toggleBtn.Position = UDim2.new(1,-34,0,4)
toggleBtn.BackgroundColor3 = C_DARKGRAY
toggleBtn.Text = "-"
toggleBtn.TextColor3 = C_WHITE
toggleBtn.Font = Enum.Font.Code
toggleBtn.TextSize = 20
toggleBtn.Parent = titleBar
local collapsed = false
toggleBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    toggleBtn.Text = collapsed and "+" or "-"
    tween(main, {Size = collapsed and UDim2.new(0,310,0,38) or UDim2.new(0,310,0,460)}, 0.3)
end)

-- khu vực chứa nút (scroll)
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-10,1,-44)
scroll.Position = UDim2.new(0,5,0,40)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = C_WHITE
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0,6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0,4)
pad.PaddingBottom = UDim.new(0,10)
pad.Parent = scroll

-- hàm tạo nút skill
local function createButton(name, color, order, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-10,0,42)
    b.Position = UDim2.new(0,5,0,0)
    b.BackgroundColor3 = C_DARKGRAY
    b.BorderSizePixel = 0
    b.Text = name
    b.TextColor3 = color or C_WHITE
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.TextWrapped = true
    b.LayoutOrder = order
    b.AutoButtonColor = true
    b.Parent = scroll
    local st = Instance.new("UIStroke")
    st.Color = color or C_GRAY
    st.Thickness = 1
    st.Transparency = 0.5
    st.Parent = b
    local cooldown = false
    b.MouseButton1Click:Connect(function()
        if cooldown then return end
        cooldown = true
        b.BackgroundColor3 = C_BLACK
        task.spawn(function() pcall(callback) end)
        task.delay(0.15, function() b.BackgroundColor3 = C_DARKGRAY end)
        task.delay(1.2, function() cooldown = false end)
    end)
    return b
end

-- ==================================================================
--   TẠO LƯỠI HÁI ĐEN (Black Scythe) + tư thế cầm
-- ==================================================================
local function weldScytheToHand()
    local c = char()
    local rightHand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
    if not rightHand then return end

    -- xóa cái cũ nếu có
    if scytheModel then scytheModel:Destroy() end

    scytheModel = Instance.new("Model")
    scytheModel.Name = "BlackScythe"

    -- cán dài
    local handle = fxPart({
        Name = "Handle",
        Size = Vector3.new(0.35, 5, 0.35),
        Color = C_BLACK,
        Material = Enum.Material.SmoothPlastic,
        Anchored = false,
        CanCollide = false,
    })
    handle.Parent = scytheModel

    -- đầu lưỡi (dựng cong bằng nhiều phần)
    local blade1 = fxPart({
        Name = "Blade1",
        Size = Vector3.new(0.25, 2.8, 1.2),
        Color = C_BLACK,
        Material = Enum.Material.Neon,
        Anchored = false,
        CanCollide = false,
    })
    blade1.Parent = scytheModel

    local blade2 = fxPart({
        Name = "Blade2",
        Size = Vector3.new(0.25, 1.8, 0.9),
        Color = C_WHITE,
        Material = Enum.Material.Neon,
        Anchored = false,
        CanCollide = false,
        Transparency = 0.3,
    })
    blade2.Parent = scytheModel

    -- điểm mấu lưỡi (mũi nhọn)
    local tip = fxPart({
        Name = "Tip",
        Size = Vector3.new(0.2, 0.2, 0.2),
        Color = C_WHITE,
        Material = Enum.Material.Neon,
        Anchored = false,
        CanCollide = false,
    })
    tip.Parent = scytheModel

    scytheModel.PrimaryPart = handle

    -- hàn các bộ phận vào handle
    local function weld(a, b, c0)
        local w = Instance.new("Weld")
        w.Part0 = a
        w.Part1 = b
        w.C0 = c0 or CFrame.new()
        w.Parent = a
        return w
    end
    weld(handle, blade1, CFrame.new(0, 2.6, 0.6) * CFrame.Angles(math.rad(50), 0, math.rad(25)))
    weld(handle, blade2, CFrame.new(0, 2.6, 0.65) * CFrame.Angles(math.rad(50), 0, math.rad(25)))
    weld(handle, tip,   CFrame.new(0, 3.4, 1.4))

    -- hàn cán vào tay phải + tư thế cầm ngầu (giơ xéo)
    local grip = Instance.new("Weld")
    grip.Part0 = rightHand
    grip.Part1 = handle
    grip.C0 = CFrame.new(0.3, -0.2, 0) * CFrame.Angles(math.rad(-30), math.rad(15), math.rad(80))
    grip.Parent = rightHand

    scytheModel.Parent = c

    -- đổi tư thế tay phải: xoay vai phải để giơ lưỡi hái kiểu ngầu
    local rightShoulder = c:FindFirstChild("Right Shoulder", true) or c:FindFirstChild("RightShoulder", true)
    if rightShoulder and rightShoulder:IsA("Motor6D") then
        rightShoulder.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(-80), math.rad(20), math.rad(-30))
    end

    -- aura đen quanh lưỡi hái
    local aura = Instance.new("ParticleEmitter")
    aura.Texture = "rbxassetid://154966922"
    aura.Color = ColorSequence.new(C_BLACK, C_GRAY)
    aura.Size = NumberSequence.new(1.5, 0.2)
    aura.Transparency = NumberSequence.new(0.4, 1)
    aura.Rate = 25
    aura.Lifetime = NumberRange.new(0.5, 1)
    aura.Speed = NumberRange.new(2, 5)
    aura.Parent = blade1
end

-- đổi toàn thân thành màu đen (monochrome)
local savedColors = {}
local function turnBodyBlack()
    local c = char()
    savedColors = {}
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then
            savedColors[v] = v.Color
            tween(v, {Color = C_BLACK}, 0.6)
            if v.Name ~= "HumanoidRootPart" then
                v.Material = Enum.Material.SmoothPlastic
            end
        elseif v:IsA("BodyColors") then
            savedColors[v] = {HeadColor=v.HeadColor, TorsoColor=v.TorsoColor, LeftArmColor=v.LeftArmColor, RightArmColor=v.RightArmColor, LeftLegColor=v.LeftLegColor, RightLegColor=v.RightLegColor}
            v.HeadColor = C_BLACK; v.TorsoColor = C_BLACK
            v.LeftArmColor = C_BLACK; v.RightArmColor = C_BLACK
            v.LeftLegColor = C_BLACK; v.RightLegColor = C_BLACK
        end
    end
    -- mặt: đổi mặt thành trắng tuyền (mắt đỏ) - đáng sợ
    local head = c:FindFirstChild("Head")
    if head then
        local face = head:FindFirstChild("face") or head:FindFirstChild("Face")
        if face then face.Transparency = 1 end
        local mesh = head:FindFirstChildWhichIsA("SpecialMesh")
        -- mắt đỏ glow
        for _, side in ipairs({"Left", "Right"}) do
            local eye = fxPart({
                Name = side.."Eye",
                Size = Vector3.new(0.15,0.15,0.05),
                Color = C_RED,
                Material = Enum.Material.Neon,
                Parent = head,
                Anchored = false,
                CanCollide = false,
            })
            local ew = Instance.new("Weld")
            ew.Part0 = head
            ew.Part1 = eye
            ew.C0 = CFrame.new(side=="Left" and -0.2 or 0.2, 0.1, -0.6)
            ew.Parent = head
        end
    end
    -- aura khói đen quanh người
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if hrp then
        local smoke = Instance.new("ParticleEmitter")
        smoke.Name = "DarkAura"
        smoke.Texture = "rbxassetid://154966922"
        smoke.Color = ColorSequence.new(C_BLACK, C_DARKGRAY)
        smoke.Size = NumberSequence.new(3, 0.5)
        smoke.Transparency = NumberSequence.new(0.5, 1)
        smoke.Rate = 40
        smoke.Lifetime = NumberRange.new(1, 2)
        smoke.Speed = NumberRange.new(1, 3)
        smoke.Parent = hrp
    end
end

local function restoreBody()
    local c = char()
    for v, col in pairs(savedColors) do
        if v and v.Parent then
            if v:IsA("BasePart") then
                tween(v, {Color = col}, 0.5)
            elseif v:IsA("BodyColors") and type(col)=="table" then
                v.HeadColor=col.HeadColor; v.TorsoColor=col.TorsoColor
                v.LeftArmColor=col.LeftArmColor; v.RightArmColor=col.RightArmColor
                v.LeftLegColor=col.LeftLegColor; v.RightLegColor=col.RightLegColor
            end
        end
    end
    savedColors = {}
    -- xóa mắt đỏ + aura
    for _, v in ipairs(c:GetDescendants()) do
        if v.Name == "LeftEye" or v.Name == "RightEye" or v.Name == "DarkAura" then
            v:Destroy()
        end
    end
    if scytheModel then scytheModel:Destroy(); scytheModel = nil end
end

-- ==================================================================
--   NÚT BIẾN HÌNH (Transform)
-- ==================================================================
createButton("[ BIẾN HÌNH ] - Lưỡi hái đen", C_RED, 1, function()
    transformed = not transformed
    if transformed then
        -- hiệu ứng biến hình: cột sáng trắng bốc lên
        local r, _ = root()
        local pillar = fxPart({
            Size = Vector3.new(6, 0.5, 6),
            Color = C_WHITE,
            Material = Enum.Material.Neon,
            CFrame = r.CFrame * CFrame.new(0, -2, 0),
            Transparency = 0.3,
        })
        tween(pillar, {Size = Vector3.new(8, 30, 8), Transparency = 1}, 0.8)
        task.delay(0.9, function() pillar:Destroy() end)
        task.wait(0.3)
        weldScytheToHand()
        turnBodyBlack()
    else
        restoreBody()
    end
end)

-- ==================================================================
--   NÚT ĐÁNH THƯỜNG (quơ lưỡi hái qua lại)
-- ==================================================================
createButton("⚔ ĐÁNH THƯỜNG (quơ lưỡi hái)", C_WHITE, 2, function()
    local c = char()
    local r, hum = root()
    if not scytheModel then weldScytheToHand() end
    local rightHand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
    if not rightHand then return end
    local grip = rightHand:FindFirstChildWhichIsA("Weld")
    -- quơ 3 nhát liên tiếp
    for i = 1, 3 do
        if grip then
            local base = CFrame.new(0.3, -0.2, 0) * CFrame.Angles(math.rad(-30), math.rad(15), math.rad(80))
            tween(grip, {C0 = base * CFrame.Angles(0, math.rad(120), 0)}, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            task.wait(0.12)
            tween(grip, {C0 = base * CFrame.Angles(0, math.rad(-120), 0)}, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            task.wait(0.12)
            tween(grip, {C0 = base}, 0.1)
        end
        -- hiệu ứng vết chém trắng cong
        local slash = fxPart({
            Size = Vector3.new(0.3, 8, 0.3),
            Color = C_WHITE,
            Material = Enum.Material.Neon,
            CFrame = r.CFrame * CFrame.new(0, 2, -3) * CFrame.Angles(0, math.rad(i*40), math.rad(45)),
            Transparency = 0.2,
        })
        tween(slash, {Transparency = 1, Size = Vector3.new(0.3, 12, 0.3)}, 0.3)
        task.delay(0.35, function() slash:Destroy() end)
        damageNearby(r.Position + r.CFrame.LookVector * 5, 7, 15)
        task.wait(0.15)
    end
end)

-- ==================================================================
--   CHIÊU CUỐI (Ultimate - cực ngầu, vừa đáng sợ vừa kinh khủng)
-- ==================================================================
createButton("💀 CHIÊU CUỐI - SỨC MẠNH NULL", C_RED, 3, function()
    local r, hum = root()
    local c = char()
    -- 1. màn hình tối sầm lại
    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1,0,1,0)
    flash.BackgroundColor3 = C_BLACK
    flash.BackgroundTransparency = 1
    flash.ZIndex = 999
    flash.Parent = gui
    tween(flash, {BackgroundTransparency = 0}, 0.5)
    task.wait(0.6)
    -- chữ NULL hiện lên giữa màn hình với glitch đỏ
    local ultText = Instance.new("TextLabel")
    ultText.Size = UDim2.new(0, 600, 0, 150)
    ultText.Position = UDim2.new(0.5, -300, 0.5, -75)
    ultText.BackgroundTransparency = 1
    ultText.Text = "NULL"
    ultText.Font = Enum.Font.Code
    ultText.TextSize = 120
    ultText.TextColor3 = C_RED
    ultText.TextStrokeTransparency = 0
    ultText.TextStrokeColor3 = C_BLACK
    ultText.ZIndex = 1000
    ultText.Parent = gui
    task.spawn(function()
        for i = 1, 20 do
            ultText.Position = UDim2.new(0.5, -300 + math.random(-15,15), 0.5, -75 + math.random(-10,10))
            ultText.TextTransparency = math.random(0,5)/10
            task.wait(0.05)
        end
    end)
    task.wait(0.8)
    -- 2. lưỡi hái KHỔNG LỒ từ trời rơi xuống
    local giantScythe = fxPart({
        Size = Vector3.new(3, 60, 3),
        Color = C_BLACK,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(r.Position + Vector3.new(0, 80, 0)) * CFrame.Angles(math.rad(20), 0, math.rad(45)),
        Transparency = 0,
    })
    local giantBlade = fxPart({
        Size = Vector3.new(2, 30, 25),
        Color = C_WHITE,
        Material = Enum.Material.Neon,
        CFrame = giantScythe.CFrame * CFrame.new(0, 25, 12),
        Transparency = 0.2,
    })
    tween(giantScythe, {CFrame = CFrame.new(r.Position + Vector3.new(0, 5, 0)) * CFrame.Angles(math.rad(70), 0, math.rad(45))}, 0.7, Enum.EasingStyle.Bounce)
    tween(giantBlade, {CFrame = CFrame.new(r.Position + Vector3.new(0, 5, 0)) * CFrame.Angles(math.rad(70), 0, math.rad(45)) * CFrame.new(0, 25, 12)}, 0.7, Enum.EasingStyle.Bounce)
    task.wait(0.7)
    -- 3. va chạm: sóng xung kích trắng lan rộng + damage toàn bản đồ
    local shock = fxPart({
        Size = Vector3.new(2, 2, 2),
        Color = C_WHITE,
        Material = Enum.Material.Neon,
        Shape = Enum.PartType.Ball,
        CFrame = r.CFrame,
        Transparency = 0.1,
    })
    tween(shock, {Size = Vector3.new(200, 200, 200), Transparency = 1}, 1.2)
    damageNearby(r.Position, 120, 200, false)
    -- rung camera
    task.spawn(function()
        for i = 1, 15 do
            camera.CFrame = camera.CFrame * CFrame.new(math.random(-2,2)/2, math.random(-2,2)/2, 0)
            task.wait(0.03)
        end
    end)
    task.wait(1.2)
    giantScythe:Destroy(); giantBlade:Destroy(); shock:Destroy()
    tween(flash, {BackgroundTransparency = 1}, 0.5)
    ultText:Destroy()
    task.delay(0.6, function() flash:Destroy() end)
end)

-- ngăn cách
local sep = Instance.new("Frame")
sep.Size = UDim2.new(1,-10,0,2)
sep.BackgroundColor3 = C_WHITE
sep.BackgroundTransparency = 0.7
sep.LayoutOrder = 4
sep.Parent = scroll

-- ==================================================================
--   20 CHỨC NĂNG / SKILL  (mỗi cái hình thái khác nhau)
-- ==================================================================

-- 1. PHÂN THÂN (Shadow Clones) - 3 bản sao đen trắng
createButton("1. PHÂN THÂN (3 bóng nhân bản)", C_WHITE, 10, function()
    local c = char(); local r = root()
    -- xóa phân thân cũ
    for _, cl in ipairs(clones) do if cl then cl:Destroy() end end
    clones = {}
    for i = 1, 3 do
        local cl = c:Clone()
        -- xóa script trong bản sao để tránh lỗi
        for _, s in ipairs(cl:GetDescendants()) do
            if s:IsA("Script") or s:IsA("LocalScript") then s:Destroy() end
        end
        cl.Parent = Workspace
        -- di chuyển ra xung quanh
        local angle = (i/3)*math.pi*2
        local offset = Vector3.new(math.cos(angle)*6, 0, math.sin(angle)*6)
        local hrp = cl:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(r.Position + offset)
        end
        -- hóa đen
        for _, v in ipairs(cl:GetDescendants()) do
            if v:IsA("BasePart") then v.Color = C_BLACK; v.Transparency = 0.2 end
        end
        -- làm clone nhảy lung tung (tấn công)
        task.spawn(function()
            local t = 0
            while cl.Parent and t < 12 do
                t = t + 0.5
                local chum = cl:FindFirstChild("Humanoid")
                if chum then chum:MoveTo(r.Position + Vector3.new(math.random(-8,8), 0, math.random(-8,8))) end
                damageNearby(hrp and hrp.Position or r.Position, 5, 8)
                task.wait(0.5)
            end
            if cl then fadeDestroy(cl:FindFirstChild("HumanoidRootPart") or cl, 0.5); cl:Destroy() end
        end)
        table.insert(clones, cl)
    end
end)

-- 2. NIỆM CHÚ (Incantation) - vòng tròn ma thuật + chùm sáng
createButton("2. NIỆM CHÚ (vòng tròn pháp thuật)", C_WHITE, 11, function()
    local r = root()
    -- vòng tròn dưới chân
    local ring = fxPart({
        Size = Vector3.new(15, 0.3, 15),
        Color = C_WHITE,
        Material = Enum.Material.Neon,
        Shape = Enum.PartType.Cylinder,
        CFrame = r.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(0,0,math.rad(90)),
        Transparency = 0.3,
    })
    tween(ring, {Transparency = 0}, 0.3)
    -- quay vòng
    local conn; conn = RunService.Heartbeat:Connect(function(dt)
        if ring.Parent then ring.CFrame = ring.CFrame * CFrame.Angles(0, dt*2, 0) else conn:Disconnect() end
    end)
    task.wait(1)
    -- chùm sáng trắng bắn từ trời xuống trung tâm
    local beam = fxPart({
        Size = Vector3.new(4, 60, 4),
        Color = C_WHITE,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(r.Position + Vector3.new(0, 30, 0)),
        Transparency = 0.5,
    })
    tween(beam, {Size = Vector3.new(10, 60, 10), Transparency = 1}, 0.8)
    damageNearby(r.Position, 12, 40)
    task.delay(1, function() ring:Destroy(); beam:Destroy() end)
end)

-- 3. MƯA LƯỠI HÁI (Scythe Rain)
createButton("3. MƯA LƯỠI HÁI (rơi từ trời)", C_WHITE, 12, function()
    local r = root()
    for i = 1, 15 do
        task.spawn(function()
            local pos = r.Position + Vector3.new(math.random(-25,25), 40, math.random(-25,25))
            local s = fxPart({
                Size = Vector3.new(0.5, 6, 2),
                Color = C_BLACK,
                Material = Enum.Material.Neon,
                CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(45), math.random(0,360), 0),
            })
            tween(s, {CFrame = CFrame.new(pos - Vector3.new(0, 40, 0)) * CFrame.Angles(math.rad(45), math.random(0,360), 0)}, 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.wait(0.8)
            local burst = fxPart({Size=Vector3.new(3,3,3), Color=C_WHITE, Shape=Enum.PartType.Ball, CFrame=s.CFrame, Transparency=0.2})
            tween(burst, {Transparency=1, Size=Vector3.new(8,8,8)}, 0.4)
            damageNearby(s.Position, 5, 12)
            s:Destroy(); task.delay(0.4, function() burst:Destroy() end)
        end)
        task.wait(0.08)
    end
end)

-- 4. SÓNG ĐEN TUYỆT VỌNG (Dark Pulse) - thay cho nổ
createButton("4. SÓNG ĐEN TUYỆT VỌNG (xung kích)", C_WHITE, 13, function()
    local r = root()
    for i = 1, 3 do
        local wave = fxPart({
            Size = Vector3.new(2, 8, 2),
            Color = i%2==0 and C_BLACK or C_WHITE,
            Material = Enum.Material.Neon,
            Shape = Enum.PartType.Ball,
            CFrame = r.CFrame,
            Transparency = 0.3,
        })
        tween(wave, {Size = Vector3.new(40+i*15, 40+i*15, 40+i*15), Transparency = 1}, 0.8)
        damageNearby(r.Position, 30+i*10, 15)
        task.wait(0.25)
        task.delay(1, function() wave:Destroy() end)
    end
end)

-- 5. XIỀNG XÍCH ĐEN (Black Chains) - trói kẻ địch
createButton("5. XIỀNG XÍCH ĐEN (trói chân địch)", C_WHITE, 14, function()
    local r = root()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= char() and v.Health > 0 then
            local p = v.Parent; local hrp = p:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - r.Position).Magnitude < 30 then
                for i = 1, 5 do
                    local chain = fxPart({
                        Size = Vector3.new(0.4, 0.4, 3),
                        Color = C_BLACK,
                        Material = Enum.Material.Metal,
                        CFrame = hrp.CFrame * CFrame.new(0, -2, 0) * CFrame.Angles(0, math.rad(i*72), 0) * CFrame.new(2,0,0),
                    })
                    tween(chain, {Transparency = 1}, 2)
                    task.delay(2, function() chain:Destroy() end)
                end
                pcall(function() v.WalkSpeed = 0 end)
                task.delay(3, function() pcall(function() v.WalkSpeed = 16 end) end)
                damageNearby(hrp.Position, 3, 20)
            end
        end
    end
end)

-- 6. LỬA ĐEN (Black Flame) - cột lửa
createButton("6. LỬA ĐEN (cột lửa hắc ám)", C_WHITE, 15, function()
    local r = root()
    local target = r.Position + r.CFrame.LookVector * 10
    local flame = fxPart({
        Size = Vector3.new(3, 0.5, 3),
        Color = C_BLACK,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(target),
        Transparency = 0.2,
    })
    tween(flame, {Size = Vector3.new(6, 25, 6)}, 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local pe = Instance.new("ParticleEmitter")
    pe.Color = ColorSequence.new(C_BLACK, C_DARKGRAY)
    pe.Size = NumberSequence.new(2, 0.5)
    pe.Transparency = NumberSequence.new(0.3, 1)
    pe.Rate = 60
    pe.Lifetime = NumberRange.new(0.8, 1.5)
    pe.Speed = NumberRange.new(5, 10)
    pe.Parent = flame
    damageNearby(target, 8, 30)
    task.delay(2.5, function() flame:Destroy() end)
end)

-- 7. SÉT ĐEN (Black Lightning)
createButton("7. SÉT ĐEN (sét hắc ám đánh xuống)", C_WHITE, 16, function()
    local r = root()
    for i = 1, 5 do
        local target = r.Position + Vector3.new(math.random(-15,15), 0, math.random(-15,15))
        local bolt = fxPart({
            Size = Vector3.new(0.8, 40, 0.8),
            Color = C_WHITE,
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(target + Vector3.new(0, 20, 0)) * CFrame.Angles(math.rad(math.random(-15,15)), math.rad(math.random(-15,15)), 0),
            Transparency = 0.1,
        })
        tween(bolt, {Transparency = 1}, 0.3)
        damageNearby(target, 6, 25)
        task.delay(0.35, function() bolt:Destroy() end)
        task.wait(0.1)
    end
end)

-- 8. BĂNG ĐEN (Black Ice) - đóng băng khu vực
createButton("8. BĂNG ĐEN (đóng băng toàn vùng)", C_WHITE, 17, function()
    local r = root()
    local ice = fxPart({
        Size = Vector3.new(30, 0.5, 30),
        Color = C_WHITE,
        Material = Enum.Material.Ice,
        CFrame = r.CFrame * CFrame.new(0, -2.8, 0),
        Transparency = 0.4,
    })
    tween(ice, {Transparency = 0.2, Size = Vector3.new(40, 0.5, 40)}, 0.5)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= char() then
            local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - r.Position).Magnitude < 20 then
                pcall(function() v.WalkSpeed = 2; v.JumpPower = 0 end)
                for _, part in ipairs(v.Parent:GetChildren()) do
                    if part:IsA("BasePart") then tween(part, {Color = C_WHITE, Transparency = 0.3}, 0.3) end
                end
                task.delay(4, function()
                    pcall(function() v.WalkSpeed = 16; v.JumpPower = 50 end)
                end)
            end
        end
    end
    damageNearby(r.Position, 20, 15)
    task.delay(4, function() ice:Destroy() end)
end)

-- 9. GIÓ CẮT (Wind Slash) - sóng lưỡi hái bay thẳng
createButton("9. GIÓ CẮT (sóng lưỡi hái bay)", C_WHITE, 18, function()
    local r = root()
    for i = 1, 3 do
        local slash = fxPart({
            Size = Vector3.new(0.3, 8, 4),
            Color = C_WHITE,
            Material = Enum.Material.Neon,
            CFrame = r.CFrame * CFrame.new(0, 2, 2) * CFrame.Angles(0, math.rad((i-2)*15), 0),
            Transparency = 0.2,
        })
        local dir = (slash.CFrame.LookVector)
        tween(slash, {CFrame = slash.CFrame + dir * 60, Transparency = 1, Size = Vector3.new(0.3, 12, 6)}, 1, Enum.EasingStyle.Linear)
        damageNearby(r.Position + dir * 30, 8, 20)
        task.delay(1.1, function() slash:Destroy() end)
        task.wait(0.15)
    end
end)

-- 10. HÚT MÁU / HÚT HỒN (Soul Drain)
createButton("10. HÚT HỒN (drain năng lượng)", C_WHITE, 19, function()
    local r = root(); local c = char(); local hum = c:FindFirstChild("Humanoid")
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= char() and v.Health > 0 then
            local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - r.Position).Magnitude < 25 then
                -- dây hút trắng từ địch về mình
                local beam = Instance.new("Beam")
                local a0 = Instance.new("Attachment", r); local a1 = Instance.new("Attachment", hrp)
                beam.Attachment0 = a0; beam.Attachment1 = a1
                beam.Color = ColorSequence.new(C_WHITE, C_BLACK)
                beam.Width0 = 0.5; beam.Width1 = 0.5
                beam.Transparency = NumberSequence.new(0.2)
                beam.Parent = r
                task.delay(1.5, function() beam:Destroy(); a0:Destroy(); a1:Destroy() end)
                for i = 1, 5 do
                    damageNearby(hrp.Position, 3, 6)
                    pcall(function() if hum then hum.Health = math.min(hum.MaxHealth, hum.Health + 6) end end)
                    task.wait(0.3)
                end
            end
        end
    end
end)

-- 11. KHIÊN BÓNG ĐÊM (Dark Shield)
createButton("11. KHIÊN BÓNG ĐÊM (khiên cầu)", C_WHITE, 20, function()
    local r = root()
    if shieldActive and shieldPart then shieldPart:Destroy(); shieldActive=false; return end
    shieldActive = true
    shieldPart = fxPart({
        Size = Vector3.new(12, 12, 12),
        Color = C_BLACK,
        Material = Enum.Material.ForceField,
        Shape = Enum.PartType.Ball,
        CFrame = r.CFrame,
        Transparency = 0.5,
    })
    local conn; conn = RunService.Heartbeat:Connect(function()
        if shieldPart and shieldPart.Parent and r.Parent then
            shieldPart.CFrame = r.CFrame
        else
            conn:Disconnect()
        end
    end)
    task.delay(10, function()
        if shieldPart then shieldPart:Destroy(); shieldPart = nil; shieldActive = false end
    end)
end)

-- 12. DỊCH CHUYỂN (Blink / Teleport)
createButton("12. DỊCH CHUYỂN (nháy mắt)", C_WHITE, 21, function()
    local r = root()
    -- hiệu ứng tan biến
    local poof = fxPart({Size=Vector3.new(5,5,5), Color=C_BLACK, Shape=Enum.PartType.Ball, CFrame=r.CFrame, Transparency=0.3})
    tween(poof, {Transparency=1, Size=Vector3.new(10,10,10)}, 0.3)
    task.delay(0.4, function() poof:Destroy() end)
    r.CFrame = r.CFrame + r.CFrame.LookVector * 25
    local poof2 = fxPart({Size=Vector3.new(10,10,10), Color=C_WHITE, Shape=Enum.PartType.Ball, CFrame=r.CFrame, Transparency=0.5})
    tween(poof2, {Transparency=1, Size=Vector3.new(3,3,3)}, 0.4)
    task.delay(0.5, function() poof2:Destroy() end)
end)

-- 13. TỐC BỘ (Flash Step - để lại afterimage)
createButton("13. TỐC BỘ (giông phong)", C_WHITE, 22, function()
    local r = root(); local c = char()
    local hum = c:FindFirstChild("Humanoid")
    local origSpeed = hum and hum.WalkSpeed or 16
    pcall(function() hum.WalkSpeed = 120 end)
    -- afterimage
    for i = 1, 8 do
        task.spawn(function()
            local ghost = c:Clone()
            for _, s in ipairs(ghost:GetDescendants()) do
                if s:IsA("Script") or s:IsA("LocalScript") or s:IsA("Humanoid") then s:Destroy() end
            end
            ghost.Parent = Workspace
            for _, v in ipairs(ghost:GetDescendants()) do if v:IsA("BasePart") then v.Transparency = 0.7; v.Color = C_WHITE; v.Anchored=true; v.CanCollide=false end end
            local ghrp = ghost:FindFirstChild("HumanoidRootPart")
            if ghrp then ghrp.CFrame = r.CFrame end
            task.delay(0.8, function() ghost:Destroy() end)
        end)
        task.wait(0.1)
    end
    task.delay(2, function() pcall(function() hum.WalkSpeed = origSpeed end) end)
end)

-- 14. BAY (Dark Wings - cánh đen)
createButton("14. BAY (cánh bóng đêm)", C_WHITE, 23, function()
    flying = not flying
    local r, hum = root()
    if flying then
        pcall(function() hum.PlatformStand = true end)
        -- cánh đen
        for _, side in ipairs({-1, 1}) do
            local wing = fxPart({
                Size = Vector3.new(8, 0.2, 4),
                Color = C_BLACK,
                Material = Enum.Material.Neon,
                CFrame = r.CFrame * CFrame.new(side*4, 1, 0) * CFrame.Angles(0, 0, math.rad(side*30)),
                Anchored = false,
                CanCollide = false,
            })
            local ww = Instance.new("Weld")
            ww.Part0 = r; ww.Part1 = wing
            ww.C0 = CFrame.new(side*4, 1, 0) * CFrame.Angles(0, 0, math.rad(side*30))
            ww.Parent = r
            wing.Name = "DarkWing"
        end
        local bp = Instance.new("BodyVelocity")
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.Velocity = Vector3.new(0,0,0)
        bp.Name = "FlyVel"
        bp.Parent = r
        flyConn = RunService.RenderStepped:Connect(function()
            local cam = Workspace.CurrentCamera
            if not bp.Parent then return end
            local fwd = UserInput:IsKeyDown(Enum.KeyCode.W) and 1 or 0
            local back = UserInput:IsKeyDown(Enum.KeyCode.S) and 1 or 0
            local right = (UserInput:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInput:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
            local up = (UserInput:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInput:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)
            local vel = cam.CFrame.LookVector * 50 * (fwd - back)
                + cam.CFrame.RightVector * 50 * right
                + Vector3.new(0, 50 * up, 0)
            -- MOBILE: nếu không bấm phím nào thì bay theo hướng camera (xoay camera là bay)
            if vel.Magnitude < 1 then
                vel = cam.CFrame.LookVector * 35
            end
            bp.Velocity = vel
        end)
    else
        pcall(function() hum.PlatformStand = false end)
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        local bv = r:FindFirstChild("FlyVel"); if bv then bv:Destroy() end
        for _, v in ipairs(char():GetDescendants()) do if v.Name == "DarkWing" then v:Destroy() end end
    end
end)

-- 15. TRIỆU HỒI QUỶ (Demon Summon) - tay quỷ khổng lồ
createButton("15. TRIỆU HỒI QUỶ (tay quỷ đen)", C_WHITE, 24, function()
    local r = root()
    -- bàn tay quỷ khổng lồ từ dưới đất nhô lên
    local hand = fxPart({
        Size = Vector3.new(10, 15, 6),
        Color = C_BLACK,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(r.Position + r.CFrame.LookVector * 10 - Vector3.new(0, 20, 0)),
        Transparency = 0.1,
    })
    tween(hand, {CFrame = CFrame.new(r.Position + r.CFrame.LookVector * 10 + Vector3.new(0, 5, 0))}, 0.6, Enum.EasingStyle.Back)
    task.wait(0.6)
    -- nắm chặt rồi đập xuống
    tween(hand, {CFrame = CFrame.new(r.Position + r.CFrame.LookVector * 10 - Vector3.new(0, 10, 0)), Size = Vector3.new(15, 8, 10)}, 0.4)
    local shock = fxPart({Size=Vector3.new(2,2,2), Color=C_WHITE, Shape=Enum.PartType.Ball, CFrame=hand.CFrame, Transparency=0.2})
    tween(shock, {Size=Vector3.new(40,40,40), Transparency=1}, 0.8)
    damageNearby(hand.Position, 15, 50)
    task.delay(1.5, function() hand:Destroy(); shock:Destroy() end)
end)

-- 16. CHẬM THỜI GIAN (Time Slow)
createButton("16. CHẬM THỜI GIAN (toàn cảnh chậm lại)", C_WHITE, 25, function()
    if timeSlowConn then return end
    timeSlowConn = true
    local orig = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= char() then
            orig[v] = v.WalkSpeed
            pcall(function() v.WalkSpeed = v.WalkSpeed * 0.15 end)
        end
    end
    -- hiệu ứng xám toàn màn hình (ColorCorrection)
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Saturation = -1
    cc.Contrast = 0.3
    cc.Parent = Lighting
    task.delay(6, function()
        for v, sp in pairs(orig) do if v and v.Parent then pcall(function() v.WalkSpeed = sp end) end end
        cc:Destroy()
        timeSlowConn = false
    end)
end)

-- 17. TAY QUỶ NẮM (Demon Grasp) - ném kẻ địch lên trời
createButton("17. TAY QUỶ NẮM (ném địch lên trời)", C_WHITE, 26, function()
    local r = root()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= char() and v.Health > 0 then
            local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - r.Position).Magnitude < 20 then
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = Vector3.new(0, 80, 0)
                bv.Parent = hrp
                task.delay(0.8, function()
                    bv.Velocity = Vector3.new(0, -100, 0)
                    task.delay(0.6, function() bv:Destroy() damageNearby(hrp.Position, 5, 40) end)
                end)
                damageNearby(hrp.Position, 3, 10)
            end
        end
    end
end)

-- 18. CỘT HỦY DIỆT (Annihilation Pillar) - thay cho nổ
createButton("18. CỘT HỦY DIỆT (pillar tiêu diệt)", C_WHITE, 27, function()
    local r = root()
    local pillar = fxPart({
        Size = Vector3.new(4, 0.5, 4),
        Color = C_WHITE,
        Material = Enum.Material.Neon,
        CFrame = r.CFrame * CFrame.new(0, -3, 0),
        Transparency = 0.2,
    })
    tween(pillar, {Size = Vector3.new(15, 100, 15), Transparency = 0.5}, 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    damageNearby(r.Position, 20, 60)
    task.delay(2, function()
        tween(pillar, {Transparency = 1, Size = Vector3.new(25, 100, 25)}, 0.8)
        task.delay(0.9, function() pillar:Destroy() end)
    end)
end)

-- 19. VÒNG TAY SÁT THẦN (Grim Reaper Ring) - lưỡi hái quay quanh người
createButton("19. VÒNG SÁT THẦN (vòng lưỡi hái quay)", C_WHITE, 28, function()
    local r = root()
    if reaperRingConn then reaperRingConn:Disconnect(); reaperRingConn = nil end
    local ringParts = {}
    for i = 1, 6 do
        local s = fxPart({
            Size = Vector3.new(0.3, 4, 1.5),
            Color = i%2==0 and C_BLACK or C_WHITE,
            Material = Enum.Material.Neon,
        })
        table.insert(ringParts, s)
    end
    local angle = 0
    reaperRingConn = RunService.Heartbeat:Connect(function(dt)
        angle = angle + dt * 4
        for i, s in ipairs(ringParts) do
            if s.Parent then
                local a = angle + (i/#ringParts)*math.pi*2
                s.CFrame = CFrame.new(r.Position + Vector3.new(math.cos(a)*7, 1, math.sin(a)*7)) * CFrame.Angles(0, -a, math.rad(45))
            end
        end
        damageNearby(r.Position, 9, 5)
    end)
    task.delay(8, function()
        if reaperRingConn then reaperRingConn:Disconnect(); reaperRingConn = nil end
        for _, s in ipairs(ringParts) do if s then fadeDestroy(s, 0.5) end end
    end)
end)

-- 20. LỖ ĐEN (Black Hole) - hút kẻ địch (thay cho chức năng bùng nổ)
createButton("20. LỖ ĐEN (hút mọi thứ vào hư vô)", C_RED, 29, function()
    local r = root()
    local bh = fxPart({
        Size = Vector3.new(3,3,3),
        Color = C_BLACK,
        Material = Enum.Material.Neon,
        Shape = Enum.PartType.Ball,
        CFrame = r.CFrame * CFrame.new(0, 5, 0),
        Transparency = 0,
    })
    local ring = fxPart({
        Size = Vector3.new(8, 0.5, 8),
        Color = C_WHITE,
        Material = Enum.Material.Neon,
        Shape = Enum.PartType.Cylinder,
        CFrame = bh.CFrame * CFrame.Angles(math.rad(90),0,0),
        Transparency = 0.3,
    })
    local conn; conn = RunService.Heartbeat:Connect(function(dt)
        if not bh.Parent then conn:Disconnect(); return end
        ring.CFrame = ring.CFrame * CFrame.Angles(0, dt*5, 0)
        -- hút mọi humanoid về phía lỗ đen
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("Humanoid") and v.Parent ~= char() and v.Health > 0 then
                local hrp = v.Parent:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dir = (bh.Position - hrp.Position).Unit
                    hrp.Velocity = hrp.Velocity + dir * 30
                    if (hrp.Position - bh.Position).Magnitude < 4 then
                        damageNearby(hrp.Position, 3, 10)
                    end
                end
            end
        end
    end)
    task.delay(5, function()
        conn:Disconnect()
        -- nén lại rồi biến mất (KHÔNG dùng Explosion)
        tween(bh, {Size = Vector3.new(0.5,0.5,0.5), Transparency = 1}, 0.5)
        tween(ring, {Transparency = 1}, 0.5)
        task.delay(0.6, function() bh:Destroy(); ring:Destroy() end)
    end)
end)

-- ==================================================================
--   KHI NHÂN VẬT CHẾT -> reset trạng thái
-- ==================================================================
player.CharacterAdded:Connect(function()
    task.wait(2)
    transformed = false
    if scytheModel then scytheModel = nil end
    flying = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if reaperRingConn then reaperRingConn:Disconnect(); reaperRingConn = nil end
end)

print("[null hub] Loaded - Black Scythe Edition")
