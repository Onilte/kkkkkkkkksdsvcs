-- ============================= ATTACK (REESCRITO) =============================
local AttackMain = Tabs.Target:AddRightGroupbox("Attack", "sword")

local ATK = {
    selected = nil,
    blobmanDelay = 0.00000005,
    activeTasks = {},
    refs = {},
    massSlots = {},
    massRunning = false,
    massThreads = {},
    reGrabThreads = {},
    blobLockRunning = false,
    circleSpinRunning = false,
    loopKillRunning = false,
    pendingKillTarget = nil,
    savedFallenHeight = nil,
}

-- -------------------- helpers base --------------------
local function atkNotify(title, desc, time)
    Library:Notify({ Title = "NoKick", Description = tostring(desc), Time = time or 3, Icon = "swords" })
end

local function atkNormalizeTarget(raw)
    if type(raw) ~= "string" then return nil end
    -- tenta "Display (Name)"
    local paren = raw:match("%(([^)]+)%)")
    if paren then return paren end
    -- tenta "Display | Name"
    local pipe = raw:match("%|%s*(.+)$")
    if pipe then return pipe:gsub("%s+$", "") end
    -- nome puro
    return raw
end

local function atkTarget()
    local name = ATK.selected or SelectedTarget
    if not name then return nil end
    return Players:FindFirstChild(name)
end

local function atkHRP(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function atkHum(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function atkIsLive(char)
    local h = atkHum(char)
    return char and char.Parent and h and h.Health > 0
end

local function atkSno(part)
    if not part or not part.Parent then return end
    pcall(function() SetNetOwner:FireServer(part, part.CFrame) end)
end

local function atkDestroyLine(part)
    if not part or not part.Parent then return end
    pcall(function() DestroyLine:FireServer(part) end)
end

local function atkOwn(part)
    if not part or not part.Parent then return false end
    local po = part:FindFirstChild("PartOwner")
    return po and po:IsA("StringValue") and po.Value == plr.Name
end

local function atkClearBodies(hrp)
    if not hrp or not hrp.Parent then return end
    for _, name in ipairs({ "NoKickBP", "NoKickBG", "NoKickBV", "NoKickAP", "NoKickA0", "NoKickA1", "KickHoldBP", "KickHoldBG", "KickHoldBV", "KickHoldAP", "KickHoldAtt0", "KickBodyPosition", "KickBodyGyro" }) do
        local c = hrp:FindFirstChild(name)
        if c then pcall(function() c:Destroy() end) end
    end
end

local function atkResetHRP(hrp)
    if not hrp or not hrp.Parent then return end
    atkClearBodies(hrp)
    pcall(function()
        hrp.Anchored = false
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function atkResetHum(char)
    local h = atkHum(char)
    if h then
        pcall(function()
            h.PlatformStand = false
            h.Sit = false
            h.AutoRotate = true
        end)
    end
end

-- -------------------- ensure blobman (spawn + sit) --------------------
local function atkFindMyBlob()
    local f = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    return f and f:FindFirstChild("CreatureBlobman")
end

local function atkGetMountedBlob()
    local h = atkHum(plr.Character)
    if h and h.SeatPart and h.SeatPart.Parent and h.SeatPart.Parent.Name == "CreatureBlobman" then
        return h.SeatPart.Parent
    end
end

local function atkSitOnBlob(blob)
    if not blob or not plr.Character then return false end
    local char = plr.Character
    local h = atkHum(char)
    local hrp = atkHRP(char)
    if not h or not hrp then return false end
    local seat = blob:FindFirstChild("VehicleSeat", true)
    if not seat or not seat:IsA("VehicleSeat") then return false end
    hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
    hrp.AssemblyLinearVelocity = Vector3.zero
    pcall(function() seat:Sit(h) end)
    local t = tick() + 2
    while tick() < t do
        if atkHum(plr.Character) and atkHum(plr.Character).SeatPart == seat then
            return true
        end
        task.wait(0.05)
    end
    return atkHum(plr.Character) and atkHum(plr.Character).SeatPart == seat
end

local function atkSpawnBlob()
    local hrp = atkHRP(plr.Character)
    if not hrp then return nil end
    local ground = hrp.Position
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { plr.Character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    local r = workspace:Raycast(ground + Vector3.new(0, 60, 0), Vector3.new(0, -400), params)
    if r then ground = r.Position end
    pcall(function()
        SpawnToy:InvokeServer("CreatureBlobman", CFrame.new(ground + Vector3.new(0, 3, 0)), Vector3.new(0, 59.667, 0))
    end)
    for _ = 1, 30 do
        task.wait(0.1)
        local b = atkFindMyBlob()
        if b then return b end
    end
    return nil
end

local function atkEnsureBlob()
    if not plr.Character then
        local _, res = pcall(function() return plr.CharacterAdded:Wait() end)
        if not res then return nil end
    end
    local mounted = atkGetMountedBlob()
    if mounted then return mounted end
    local existing = atkFindMyBlob()
    if existing then
        if atkSitOnBlob(existing) then return existing end
        -- se não conseguiu sentar, tenta novo
        pcall(function() DestroyToy:FireServer(existing) end)
        task.wait(0.2)
    end
    local spawned = atkSpawnBlob()
    if not spawned then
        atkNotify("Kick", "Falha ao spawnar Blobman", 4)
        return nil
    end
    if atkSitOnBlob(spawned) then return spawned end
    -- tentou, não conseguiu, tenta mais 2x
    for _ = 1, 2 do
        if atkSitOnBlob(spawned) then return spawned end
    end
    atkNotify("Kick", "Blobman spawnou mas não sentou", 4)
    return nil
end

-- -------------------- kick com 4 constraints redundantes --------------------
local function atkApplyLock(hrp, hum, posCF)
    if not hrp or not hrp.Parent then return end
    atkClearBodies(hrp)

    local bp = Instance.new("BodyPosition")
    bp.Name = "NoKickBP"
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 50000
    bp.D = 100
    bp.Position = posCF.Position
    bp.Parent = hrp

    local bg = Instance.new("BodyGyro")
    bg.Name = "NoKickBG"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 50000
    bg.D = 150
    bg.CFrame = CFrame.lookAt(posCF.Position, posCF.Position + Vector3.new(1, 0, 0))
    bg.Parent = hrp

    local bv = Instance.new("BodyVelocity")
    bv.Name = "NoKickBV"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    local a0 = Instance.new("Attachment")
    a0.Name = "NoKickA0"
    a0.Parent = hrp
    local anchor = hrp:FindFirstChild("NoKickAnchorPart")
    if not anchor or not anchor.Parent then
        anchor = Instance.new("Part")
        anchor.Name = "NoKickAnchorPart"
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.Transparency = 1
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        anchor.Parent = workspace
    end
    anchor.CFrame = posCF
    local a1 = anchor:FindFirstChild("NoKickA1") or Instance.new("Attachment")
    a1.Name = "NoKickA1"
    a1.Parent = anchor

    local ap = Instance.new("AlignPosition")
    ap.Name = "NoKickAP"
    ap.Attachment0 = a0
    ap.Attachment1 = a1
    ap.MaxForce = math.huge
    ap.Responsiveness = 200
    ap.Mode = Enum.PositionAlignmentMode.TwoAttachment
    ap.Parent = hrp

    if hum then
        pcall(function()
            hum.PlatformStand = true
            hum.Sit = true
        end)
    end
end

local function atkTickLock(hrp, posCF)
    if not hrp or not hrp.Parent then return end
    local bp = hrp:FindFirstChild("NoKickBP")
    if bp then bp.Position = posCF.Position end
    local bg = hrp:FindFirstChild("NoKickBG")
    if bg then bg.CFrame = CFrame.lookAt(posCF.Position, posCF.Position + Vector3.new(1, 0, 0)) end
    local anchor = hrp:FindFirstChild("NoKickAnchorPart") or workspace:FindFirstChild("NoKickAnchorPart")
    if anchor then anchor.CFrame = posCF end
end

-- -------------------- GRAB REAL DO BLOBMAN --------------------
local function atkBlobGrab(blob, targetHRP, side)
    if not blob or not targetHRP or not targetHRP.Parent then return false end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    if not script then return false end
    local grab = script:FindFirstChild("CreatureGrab")
    if not grab then return false end
    local det = blob:FindFirstChild(side .. "Detector")
    if not det then return false end
    local weld = det:FindFirstChild(side .. "Weld") or det:FindFirstChild("RigidConstraint")
    if not weld then return false end
    local ok = pcall(function()
        grab:FireServer(det, targetHRP, weld)
    end)
    return ok
end

local function atkBlobDrop(blob, targetHRP, side)
    if not blob or not targetHRP then return false end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    if not script then return false end
    local drop = script:FindFirstChild("CreatureDrop") or script:FindFirstChild("CreatureRelease")
    if not drop then return false end
    local det = blob:FindFirstChild(side .. "Detector")
    if not det then return false end
    local weld = det:FindFirstChild(side .. "Weld") or det:FindFirstChild("RigidConstraint")
    if not weld then return false end
    pcall(function() drop:FireServer(weld, targetHRP) end)
    return true
end

-- -------------------- TARGET KICK (loop, 4 constraints + re-grab) --------------------
local function atkStartTargetKick(targetName, mode)
    mode = mode or "Standard"
    local taskHandle = task.spawn(function()
        local blob = atkEnsureBlob()
        if not blob then return end
        local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
        local savedBlobPos = blobRoot and blobRoot.CFrame
        local alternator = "Left"
        local savedMy = atkHRP(plr.Character) and atkHRP(plr.Character).CFrame

        while ATK.activeTasks[taskHandle] and blob and blob.Parent and ATK.selected do
            local target = atkTarget()
            if not target or not target.Character or not atkIsLive(target.Character) then
                task.wait(0.2)
                continue
            end
            local tHRP = atkHRP(target.Character)
            local tHum = atkHum(target.Character)
            if not tHRP or not tHum then task.wait(0.2); continue end

            -- re-apply grab alternando lado
            atkBlobGrab(blob, tHRP, alternator)
            alternator = alternator == "Left" and "Right" or "Left"
            task.wait(0.02)
            atkBlobGrab(blob, tHRP, alternator)

            -- aplica lock no alvo
            local myHRP = atkHRP(plr.Character)
            local lockPos
            if myHRP then
                if mode == "Above" then
                    lockPos = CFrame.new(myHRP.Position + Vector3.new(0, 25, 0))
                elseif mode == "Circle" then
                    local t = tick() * 2
                    local r = 14
                    lockPos = CFrame.new(myHRP.Position + Vector3.new(math.cos(t) * r, 22, math.sin(t) * r))
                elseif mode == "Front" then
                    lockPos = myHRP.CFrame * CFrame.new(0, 15, -10)
                else
                    lockPos = myHRP.CFrame * CFrame.new(0, 20, 0)
                end
            else
                lockPos = tHRP.CFrame
            end

            atkApplyLock(tHRP, tHum, lockPos)

            -- sno spam + destroy line spam
            for _ = 1, 3 do
                atkSno(tHRP)
                atkDestroyLine(tHRP)
            end

            -- ownership check → kill
            if atkOwn(tHRP) then
                pcall(function()
                    tHum.BreakJointsOnDeath = false
                    tHum:ChangeState(Enum.HumanoidStateType.Dead)
                    tHum.Health = 0
                end)
                atkResetHRP(tHRP)
                task.wait(1.2)
            end

            RunService.Heartbeat:Wait()
        end

        if savedBlobPos and blobRoot and blobRoot.Parent then
            pcall(function() blobRoot.CFrame = savedBlobPos end)
        end
        if savedMy and atkHRP(plr.Character) then
            pcall(function() atkHRP(plr.Character).CFrame = savedMy end)
        end
    end)
    ATK.activeTasks[taskHandle] = true
    return taskHandle
end

-- -------------------- BLOB LOCK (sem soltar) --------------------
local function atkStartBlobLock(targetName)
    local taskHandle = task.spawn(function()
        local blob = atkEnsureBlob()
        if not blob then return end
        local savedMy = atkHRP(plr.Character) and atkHRP(plr.Character).CFrame

        while ATK.activeTasks[taskHandle] and blob and blob.Parent do
            local target = atkTarget()
            if not target or not target.Character or not atkIsLive(target.Character) then
                task.wait(0.2)
                continue
            end
            local tHRP = atkHRP(target.Character)
            local tHum = atkHum(target.Character)
            if not tHRP or not tHum then task.wait(0.2); continue end

            local side = (tick() * 10) % 2 < 1 and "Left" or "Right"
            atkBlobGrab(blob, tHRP, side)
            atkSno(tHRP)
            atkDestroyLine(tHRP)
            atkApplyLock(tHRP, tHum, CFrame.new(tHRP.Position))

            if atkOwn(tHRP) then
                pcall(function()
                    tHum.BreakJointsOnDeath = false
                    tHum:ChangeState(Enum.HumanoidStateType.Dead)
                    tHum.Health = 0
                end)
                atkResetHRP(tHRP)
                task.wait(1)
            end

            RunService.Heartbeat:Wait()
        end

        if savedMy and atkHRP(plr.Character) then
            pcall(function() atkHRP(plr.Character).CFrame = savedMy end)
        end
    end)
    ATK.activeTasks[taskHandle] = true
    return taskHandle
end

-- -------------------- CIRCLE SPIN --------------------
local function atkStartCircleSpin(targetName)
    local taskHandle = task.spawn(function()
        local blob = atkEnsureBlob()
        if not blob then return end
        local savedMy = atkHRP(plr.Character) and atkHRP(plr.Character).CFrame
        local angle = 0

        while ATK.activeTasks[taskHandle] and blob and blob.Parent do
            local target = atkTarget()
            if not target or not target.Character or not atkIsLive(target.Character) then
                task.wait(0.2)
                continue
            end
            local tHRP = atkHRP(target.Character)
            local tHum = atkHum(target.Character)
            if not tHRP or not tHum then task.wait(0.2); continue end

            angle += 0.15
            local myHRP = atkHRP(plr.Character)
            if myHRP then
                local r = 20
                local pos = myHRP.Position + Vector3.new(math.cos(angle) * r, 25, math.sin(angle) * r)
                atkApplyLock(tHRP, tHum, CFrame.new(pos))
            end
            atkBlobGrab(blob, tHRP, "Left")
            atkSno(tHRP)
            atkDestroyLine(tHRP)

            if atkOwn(tHRP) then
                pcall(function()
                    tHum.BreakJointsOnDeath = false
                    tHum:ChangeState(Enum.HumanoidStateType.Dead)
                    tHum.Health = 0
                end)
                atkResetHRP(tHRP)
            end

            RunService.Heartbeat:Wait()
        end

        if savedMy and atkHRP(plr.Character) then
            pcall(function() atkHRP(plr.Character).CFrame = savedMy end)
        end
    end)
    ATK.activeTasks[taskHandle] = true
    return taskHandle
end

-- -------------------- LOOP KILL (ownership) --------------------
local function atkStartLoopKill()
    local taskHandle = task.spawn(function()
        local savedFallen = workspace.FallenPartsDestroyHeight
        workspace.FallenPartsDestroyHeight = 0/0

        while ATK.activeTasks[taskHandle] do
            local target = atkTarget()
            if not target or not target.Character or not atkIsLive(target.Character) then
                task.wait(0.2)
                continue
            end
            local tHRP = atkHRP(target.Character)
            local tHum = atkHum(target.Character)
            if not tHRP or not tHum then task.wait(0.2); continue end

            local myHRP = atkHRP(plr.Character)
            if not myHRP then task.wait(0.2); continue end

            local savedMy = myHRP.CFrame
            myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3)
            myHRP.AssemblyLinearVelocity = Vector3.zero

            for _ = 1, 5 do
                atkSno(tHRP)
                atkDestroyLine(tHRP)
            end

            if atkOwn(tHRP) then
                pcall(function()
                    tHum.BreakJointsOnDeath = false
                    tHum:ChangeState(Enum.HumanoidStateType.Dead)
                    tHum.Health = 0
                end)
                atkResetHRP(tHRP)
                task.wait(1.2)
            end

            myHRP.CFrame = savedMy
            task.wait(0.05)
        end

        pcall(function() workspace.FallenPartsDestroyHeight = savedFallen or -100 end)
    end)
    ATK.activeTasks[taskHandle] = true
    return taskHandle
end

-- -------------------- MASS KICK (5 slots) --------------------
local function atkMassTick()
    if not ATK.massRunning then return end
    for i, slot in ipairs(ATK.massSlots) do
        if slot.player and slot.player.Parent and slot.player.Character and not slot.done then
            local tHRP = atkHRP(slot.player.Character)
            local tHum = atkHum(slot.player.Character)
            if tHRP and tHum and tHum.Health > 0 then
                if not slot.thread or not coroutine.status(slot.thread) == "suspended" then
                    slot.thread = task.spawn(function()
                        while ATK.massRunning and slot.player and slot.player.Parent do
                            local char = slot.player.Character
                            local h = atkHRP(char)
                            local hum = atkHum(char)
                            if not h or not hum or hum.Health <= 0 then break end
                            atkSno(h)
                            atkDestroyLine(h)
                            atkApplyLock(h, hum, CFrame.new(h.Position + Vector3.new(0, 15, 0)))
                            if atkOwn(h) then
                                pcall(function()
                                    hum.BreakJointsOnDeath = false
                                    hum:ChangeState(Enum.HumanoidStateType.Dead)
                                    hum.Health = 0
                                end)
                                break
                            end
                            RunService.Heartbeat:Wait()
                        end
                    end)
                end
            end
        end
    end
end

local function atkMassStart()
    ATK.massRunning = true
    ATK.massThreads = {}
    for i = 1, 5 do
        ATK.massThreads[i] = task.spawn(function()
            while ATK.massRunning do
                atkMassTick()
                task.wait(0.05)
            end
        end)
    end
end

local function atkMassStop()
    ATK.massRunning = false
    for _, slot in ipairs(ATK.massSlots) do
        if slot.thread then pcall(task.cancel, slot.thread) end
        if slot.player and slot.player.Character then
            local h = atkHRP(slot.player.Character)
            if h then atkResetHRP(h) end
            atkResetHum(slot.player.Character)
        end
        slot.done = nil
    end
    for _, t in ipairs(ATK.massThreads) do
        pcall(task.cancel, t)
    end
    ATK.massThreads = {}
end

-- -------------------- STOP TUDO --------------------
local function atkStopAll()
    for t in pairs(ATK.activeTasks) do
        pcall(task.cancel, t)
    end
    ATK.activeTasks = {}
    atkMassStop()
    for _, name in ipairs({ "NoKickAnchorPart" }) do
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj.Name == name then pcall(function() obj:Destroy() end) end
        end
    end
    local target = atkTarget()
    if target and target.Character then
        local h = atkHRP(target.Character)
        if h then atkResetHRP(h) end
        atkResetHum(target.Character)
    end
end

-- -------------------- UI --------------------
AttackMain:AddDropdown("TargetDropdown_ATK", {
    Text = "Target",
    Values = (function()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= plr then
                table.insert(t, p.DisplayName .. " (" .. p.Name .. ")")
            end
        end
        return t
    end)(),
    Default = nil,
    Multi = false,
    AllowNull = true,
    MaxVisibleDropdownItems = 15,
    Callback = function(v)
        ATK.selected = atkNormalizeTarget(v)
        SelectedTarget = ATK.selected
    end,
})

AttackMain:AddButton("Refresh Target List", function()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then
            table.insert(t, p.DisplayName .. " (" .. p.Name .. ")")
        end
    end
    Options.TargetDropdown_ATK:SetValues(t)
end)

AttackMain:AddDivider()
AttackMain:AddLabel("Kick Methods", true, Color3.fromRGB(255, 150, 50))

AttackMain:AddDropdown("KickModeDD", {
    Text = "Kick Lock Mode",
    Values = { "Standard", "Above", "Circle", "Front" },
    Default = "Standard",
    Multi = false,
    Callback = function(v) ATK.lockMode = v end,
})

AttackMain:AddToggle("TargetKickToggle", {
    Text = "Target Kick (loop)",
    Default = false,
    Callback = function(v)
        if v then
            if not atkTarget() then
                atkNotify("Kick", "Selecione um alvo primeiro", 3)
                Toggles.TargetKickToggle:SetValue(false)
                return
            end
            ATK.lockMode = ATK.lockMode or "Standard"
            ATK.kickTask = atkStartTargetKick(ATK.selected, ATK.lockMode)
        else
            if ATK.kickTask then
                ATK.activeTasks[ATK.kickTask] = nil
                pcall(task.cancel, ATK.kickTask)
                ATK.kickTask = nil
            end
            atkStopAll()
        end
    end,
})

AttackMain:AddToggle("BlobLockToggle", {
    Text = "Blob Lock (trava alvo)",
    Default = false,
    Callback = function(v)
        if v then
            if not atkTarget() then
                atkNotify("Kick", "Selecione um alvo primeiro", 3)
                Toggles.BlobLockToggle:SetValue(false)
                return
            end
            ATK.blobLockTask = atkStartBlobLock(ATK.selected)
        else
            if ATK.blobLockTask then
                ATK.activeTasks[ATK.blobLockTask] = nil
                pcall(task.cancel, ATK.blobLockTask)
                ATK.blobLockTask = nil
            end
        end
    end,
})

AttackMain:AddToggle("CircleSpinToggle", {
    Text = "Circle Spin (gira alvo)",
    Default = false,
    Callback = function(v)
        if v then
            if not atkTarget() then
                atkNotify("Kick", "Selecione um alvo primeiro", 3)
                Toggles.CircleSpinToggle:SetValue(false)
                return
            end
            ATK.circleSpinTask = atkStartCircleSpin(ATK.selected)
        else
            if ATK.circleSpinTask then
                ATK.activeTasks[ATK.circleSpinTask] = nil
                pcall(task.cancel, ATK.circleSpinTask)
                ATK.circleSpinTask = nil
            end
        end
    end,
})

AttackMain:AddToggle("LoopKillToggle", {
    Text = "Loop Kill (ownership)",
    Default = false,
    Callback = function(v)
        if v then
            if not atkTarget() then
                atkNotify("Kick", "Selecione um alvo primeiro", 3)
                Toggles.LoopKillToggle:SetValue(false)
                return
            end
            ATK.loopKillTask = atkStartLoopKill()
        else
            if ATK.loopKillTask then
                ATK.activeTasks[ATK.loopKillTask] = nil
                pcall(task.cancel, ATK.loopKillTask)
                ATK.loopKillTask = nil
            end
        end
    end,
})

AttackMain:AddDivider()
AttackMain:AddLabel("One-Click", true, Color3.fromRGB(255, 150, 50))

AttackMain:AddButton("Bring Target", function()
    local target = atkTarget()
    if not target or not target.Character then atkNotify("Kick", "Sem alvo", 3); return end
    local blob = atkEnsureBlob()
    if not blob then return end
    local tHRP = atkHRP(target.Character)
    if not tHRP then return end
    atkBlobGrab(blob, tHRP, "Left")
    task.wait(0.1)
    atkBlobGrab(blob, tHRP, "Right")
end)

AttackMain:AddButton("Kick Once (kill)", function()
    local target = atkTarget()
    if not target or not target.Character then atkNotify("Kick", "Sem alvo", 3); return end
    local blob = atkEnsureBlob()
    if not blob then return end
    local tHRP = atkHRP(target.Character)
    local tHum = atkHum(target.Character)
    if not tHRP or not tHum then return end
    for _ = 1, 5 do
        atkBlobGrab(blob, tHRP, "Left")
        atkBlobGrab(blob, tHRP, "Right")
        atkSno(tHRP)
        atkDestroyLine(tHRP)
        task.wait(0.02)
    end
    if atkOwn(tHRP) then
        pcall(function()
            tHum.BreakJointsOnDeath = false
            tHum:ChangeState(Enum.HumanoidStateType.Dead)
            tHum.Health = 0
        end)
    end
end)

AttackMain:AddButton("Auto Sit Blobman", function()
    atkEnsureBlob()
end)

AttackMain:AddButton("Reset Blobman", function()
    local b = atkFindMyBlob()
    if b then pcall(function() DestroyToy:FireServer(b) end) end
    local h = atkHum(plr.Character)
    if h then h.Sit = false end
    task.wait(0.2)
    atkEnsureBlob()
end)

AttackMain:AddDivider()
AttackMain:AddLabel("Mass Kick", true, Color3.fromRGB(255, 80, 80))

for i = 1, 5 do
    AttackMain:AddDropdown("MassSlot" .. i, {
        Text = "Mass Slot " .. i,
        Values = (function()
            local t = { "None" }
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= plr then
                    table.insert(t, p.DisplayName .. " (" .. p.Name .. ")")
                end
            end
            return t
        end)(),
        Default = "None",
        Multi = false,
        Callback = function(v)
            if v == "None" or not v then
                ATK.massSlots[i] = nil
                return
            end
            local name = atkNormalizeTarget(v)
            local p = name and Players:FindFirstChild(name)
            if p then ATK.massSlots[i] = { player = p } end
        end,
    })
end

AttackMain:AddToggle("MassKickToggle", {
    Text = "Mass Kick (5 slots)",
    Default = false,
    Callback = function(v)
        if v then
            if #ATK.massSlots == 0 then
                atkNotify("Kick", "Selecione pelo menos 1 slot", 3)
                Toggles.MassKickToggle:SetValue(false)
                return
            end
            atkMassStart()
        else
            atkMassStop()
        end
    end,
})

AttackMain:AddDivider()
AttackMain:AddLabel("Utility", true, Color3.fromRGB(0, 200, 100))

AttackMain:AddToggle("AutoSitBlobToggle", {
    Text = "Auto Sit Blobman (contínuo)",
    Default = false,
    Callback = function(v)
        if v then
            ATK.autoSitThread = task.spawn(function()
                while ATK.autoSitThread and Toggles.AutoSitBlobToggle.Value do
                    atkEnsureBlob()
                    task.wait(3)
                end
            end)
        else
            if ATK.autoSitThread then
                pcall(task.cancel, ATK.autoSitThread)
                ATK.autoSitThread = nil
            end
        end
    end,
})

AttackMain:AddButton("Stop All", function()
    atkStopAll()
    for _, name in ipairs({ "TargetKickToggle", "BlobLockToggle", "CircleSpinToggle", "LoopKillToggle", "MassKickToggle", "AutoSitBlobToggle" }) do
        if Toggles[name] then Toggles[name]:SetValue(false) end
    end
end)

Library:OnUnload(function()
    atkStopAll()
end)

-- ============================= FIM ATTACK =============================
