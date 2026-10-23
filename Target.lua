-- ============================= KICKS BLOBMAN / TARGET MERCURY =============================
do
    local KickBox = Tabs.Target:AddRightGroupbox("Kicks Blobman/Target Mercury", "swords")

    local KM = {
        selected = nil,
        lockMode = "Standard",
        blobDelay = 0.00000005,
        activeTasks = {},
        massSlots = {},
        massRunning = false,
        massThreads = {},
        autoSitThread = nil,
    }

    -- ---------- helpers ----------
    local function kNotify(title, desc, time)
        Library:Notify({ Title = title or "Mercury", Description = tostring(desc), Time = time or 3, Icon = "swords" })
    end

    local function kNormalize(raw)
        if type(raw) ~= "string" then return nil end
        local paren = raw:match("%(([^)]+)%)")
        if paren then return paren end
        local pipe = raw:match("%|%s*(.+)$")
        if pipe then return pipe:gsub("%s+$", "") end
        return raw
    end

    local function kTarget()
        local name = KM.selected or SelectedTarget
        if not name then return nil end
        return Players:FindFirstChild(name)
    end

    local function kHRP(char)
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function kHum(char)
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function kLive(char)
        local h = kHum(char)
        return char and char.Parent and h and h.Health > 0
    end

    local function kSno(part)
        if not part or not part.Parent then return end
        pcall(function() SetNetOwner:FireServer(part, part.CFrame) end)
    end

    local function kDestroyLine(part)
        if not part or not part.Parent then return end
        pcall(function() DestroyLine:FireServer(part) end)
    end

    local function kOwn(part)
        if not part or not part.Parent then return false end
        local po = part:FindFirstChild("PartOwner")
        return po and po:IsA("StringValue") and po.Value == plr.Name
    end

    local function kClearBodies(hrp)
        if not hrp or not hrp.Parent then return end
        for _, name in ipairs({ "KickBP", "KickBG", "KickBV", "KickAP", "KickA0", "KickHoldBP", "KickHoldBG", "KickHoldBV", "KickHoldAP", "KickHoldAtt0" }) do
            local c = hrp:FindFirstChild(name)
            if c then pcall(function() c:Destroy() end) end
        end
    end

    local function kResetHRP(hrp)
        if not hrp or not hrp.Parent then return end
        kClearBodies(hrp)
        pcall(function()
            hrp.Anchored = false
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    local function kResetHum(char)
        local h = kHum(char)
        if h then
            pcall(function()
                h.PlatformStand = false
                h.Sit = false
                h.AutoRotate = true
            end)
        end
    end

    -- ---------- blobman ----------
    local function kFindBlob()
        local f = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        return f and f:FindFirstChild("CreatureBlobman")
    end

    local function kMountedBlob()
        local h = kHum(plr.Character)
        if h and h.SeatPart and h.SeatPart.Parent and h.SeatPart.Parent.Name == "CreatureBlobman" then
            return h.SeatPart.Parent
        end
    end

    local function kSit(blob)
        if not blob or not plr.Character then return false end
        local char = plr.Character
        local h = kHum(char)
        local hrp = kHRP(char)
        if not h or not hrp then return false end
        local seat = blob:FindFirstChild("VehicleSeat", true)
        if not seat or not seat:IsA("VehicleSeat") then return false end
        hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
        pcall(function() seat:Sit(h) end)
        local t = tick() + 2
        while tick() < t do
            local hh = kHum(plr.Character)
            if hh and hh.SeatPart == seat then return true end
            task.wait(0.05)
        end
        local hh = kHum(plr.Character)
        return hh and hh.SeatPart == seat
    end

    local function kSpawnBlob()
        local hrp = kHRP(plr.Character)
        if not hrp then return nil end
        local pos = hrp.Position
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = { plr.Character }
        params.FilterType = Enum.RaycastFilterType.Exclude
        local r = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -400), params)
        if r then pos = r.Position end
        pcall(function()
            SpawnToy:InvokeServer("CreatureBlobman", CFrame.new(pos + Vector3.new(0, 3, 0)), Vector3.new(0, 59.667, 0))
        end)
        for _ = 1, 30 do
            task.wait(0.1)
            local b = kFindBlob()
            if b then return b end
        end
        return nil
    end

    local function kEnsureBlob()
        if not plr.Character then
            local ok, res = pcall(function() return plr.CharacterAdded:Wait() end)
            if not ok or not res then return nil end
        end
        local mounted = kMountedBlob()
        if mounted then return mounted end
        local existing = kFindBlob()
        if existing then
            if kSit(existing) then return existing end
            pcall(function() DestroyToy:FireServer(existing) end)
            task.wait(0.2)
        end
        local spawned = kSpawnBlob()
        if not spawned then
            kNotify("Mercury", "Falha ao spawnar Blobman", 4)
            return nil
        end
        if kSit(spawned) then return spawned end
        for _ = 1, 2 do
            if kSit(spawned) then return spawned end
        end
        kNotify("Mercury", "Blobman spawnou mas não sentou", 4)
        return nil
    end

    -- ---------- locks ----------
    local function kApplyLock(hrp, hum, posCF)
        if not hrp or not hrp.Parent then return end
        kClearBodies(hrp)
        local bp = Instance.new("BodyPosition")
        bp.Name = "KickBP"
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.P = 50000
        bp.D = 100
        bp.Position = posCF.Position
        bp.Parent = hrp
        local bg = Instance.new("BodyGyro")
        bg.Name = "KickBG"
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 50000
        bg.D = 150
        bg.CFrame = CFrame.lookAt(posCF.Position, posCF.Position + Vector3.new(1, 0, 0))
        bg.Parent = hrp
        local bv = Instance.new("BodyVelocity")
        bv.Name = "KickBV"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.zero
        bv.Parent = hrp
        if hum then
            pcall(function()
                hum.PlatformStand = true
                hum.Sit = true
            end)
        end
    end

    local function kTickLock(hrp, posCF)
        if not hrp or not hrp.Parent then return end
        local bp = hrp:FindFirstChild("KickBP")
        if bp then bp.Position = posCF.Position end
        local bg = hrp:FindFirstChild("KickBG")
        if bg then bg.CFrame = CFrame.lookAt(posCF.Position, posCF.Position + Vector3.new(1, 0, 0)) end
    end

    -- ---------- grab real ----------
    local function kGrab(blob, tHRP, side)
        if not blob or not tHRP or not tHRP.Parent then return false end
        local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
        if not script then return false end
        local grab = script:FindFirstChild("CreatureGrab")
        if not grab then return false end
        local det = blob:FindFirstChild(side .. "Detector")
        if not det then return false end
        local weld = det:FindFirstChild(side .. "Weld") or det:FindFirstChild("RigidConstraint")
        if not weld then return false end
        pcall(function() grab:FireServer(det, tHRP, weld) end)
        return true
    end

    local function kDrop(blob, tHRP, side)
        if not blob or not tHRP then return false end
        local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
        if not script then return false end
        local drop = script:FindFirstChild("CreatureDrop") or script:FindFirstChild("CreatureRelease")
        if not drop then return false end
        local det = blob:FindFirstChild(side .. "Detector")
        if not det then return false end
        local weld = det:FindFirstChild(side .. "Weld") or det:FindFirstChild("RigidConstraint")
        if not weld then return false end
        pcall(function() drop:FireServer(weld, tHRP) end)
        return true
    end

    -- ---------- kick principal ----------
    local function startTargetKick(mode)
        mode = mode or "Standard"
        local handle = task.spawn(function()
            local blob = kEnsureBlob()
            if not blob then return end
            local alt = "Left"
            local savedMy = kHRP(plr.Character) and kHRP(plr.Character).CFrame

            while KM.activeTasks[handle] and blob and blob.Parent and (KM.selected or SelectedTarget) do
                local target = kTarget()
                if not target or not target.Character or not kLive(target.Character) then
                    task.wait(0.2)
                    continue
                end
                local tHRP = kHRP(target.Character)
                local tHum = kHum(target.Character)
                if not tHRP or not tHum then task.wait(0.2); continue end

                kGrab(blob, tHRP, alt)
                alt = alt == "Left" and "Right" or "Left"
                task.wait(0.02)
                kGrab(blob, tHRP, alt)

                local myHRP = kHRP(plr.Character)
                local lockPos
                if myHRP then
                    if mode == "Above" then
                        lockPos = CFrame.new(myHRP.Position + Vector3.new(0, 25, 0))
                    elseif mode == "Circle" then
                        local t = tick() * 2
                        lockPos = CFrame.new(myHRP.Position + Vector3.new(math.cos(t) * 14, 22, math.sin(t) * 14))
                    elseif mode == "Front" then
                        lockPos = myHRP.CFrame * CFrame.new(0, 15, -10)
                    else
                        lockPos = myHRP.CFrame * CFrame.new(0, 20, 0)
                    end
                else
                    lockPos = tHRP.CFrame
                end

                kApplyLock(tHRP, tHum, lockPos)
                for _ = 1, 3 do
                    kSno(tHRP)
                    kDestroyLine(tHRP)
                end

                if kOwn(tHRP) then
                    pcall(function()
                        tHum.BreakJointsOnDeath = false
                        tHum:ChangeState(Enum.HumanoidStateType.Dead)
                        tHum.Health = 0
                    end)
                    kResetHRP(tHRP)
                    task.wait(1.2)
                end

                RunService.Heartbeat:Wait()
            end

            if savedMy and kHRP(plr.Character) then
                pcall(function() kHRP(plr.Character).CFrame = savedMy end)
            end
        end)
        KM.activeTasks[handle] = true
        return handle
    end

    -- ---------- blob lock ----------
    local function startBlobLock()
        local handle = task.spawn(function()
            local blob = kEnsureBlob()
            if not blob then return end
            local savedMy = kHRP(plr.Character) and kHRP(plr.Character).CFrame

            while KM.activeTasks[handle] and blob and blob.Parent do
                local target = kTarget()
                if not target or not target.Character or not kLive(target.Character) then
                    task.wait(0.2)
                    continue
                end
                local tHRP = kHRP(target.Character)
                local tHum = kHum(target.Character)
                if not tHRP or not tHum then task.wait(0.2); continue end

                local side = (tick() * 10) % 2 < 1 and "Left" or "Right"
                kGrab(blob, tHRP, side)
                kSno(tHRP)
                kDestroyLine(tHRP)
                kApplyLock(tHRP, tHum, CFrame.new(tHRP.Position))

                if kOwn(tHRP) then
                    pcall(function()
                        tHum.BreakJointsOnDeath = false
                        tHum:ChangeState(Enum.HumanoidStateType.Dead)
                        tHum.Health = 0
                    end)
                    kResetHRP(tHRP)
                    task.wait(1)
                end

                RunService.Heartbeat:Wait()
            end

            if savedMy and kHRP(plr.Character) then
                pcall(function() kHRP(plr.Character).CFrame = savedMy end)
            end
        end)
        KM.activeTasks[handle] = true
        return handle
    end

    -- ---------- circle spin ----------
    local function startCircleSpin()
        local handle = task.spawn(function()
            local blob = kEnsureBlob()
            if not blob then return end
            local savedMy = kHRP(plr.Character) and kHRP(plr.Character).CFrame
            local angle = 0

            while KM.activeTasks[handle] and blob and blob.Parent do
                local target = kTarget()
                if not target or not target.Character or not kLive(target.Character) then
                    task.wait(0.2)
                    continue
                end
                local tHRP = kHRP(target.Character)
                local tHum = kHum(target.Character)
                if not tHRP or not tHum then task.wait(0.2); continue end

                angle += 0.15
                local myHRP = kHRP(plr.Character)
                if myHRP then
                    local pos = myHRP.Position + Vector3.new(math.cos(angle) * 20, 25, math.sin(angle) * 20)
                    kApplyLock(tHRP, tHum, CFrame.new(pos))
                end
                kGrab(blob, tHRP, "Left")
                kSno(tHRP)
                kDestroyLine(tHRP)

                if kOwn(tHRP) then
                    pcall(function()
                        tHum.BreakJointsOnDeath = false
                        tHum:ChangeState(Enum.HumanoidStateType.Dead)
                        tHum.Health = 0
                    end)
                    kResetHRP(tHRP)
                end

                RunService.Heartbeat:Wait()
            end

            if savedMy and kHRP(plr.Character) then
                pcall(function() kHRP(plr.Character).CFrame = savedMy end)
            end
        end)
        KM.activeTasks[handle] = true
        return handle
    end

    -- ---------- loop kill ----------
    local function startLoopKill()
        local handle = task.spawn(function()
            local savedFallen = workspace.FallenPartsDestroyHeight
            workspace.FallenPartsDestroyHeight = 0/0

            while KM.activeTasks[handle] do
                local target = kTarget()
                if not target or not target.Character or not kLive(target.Character) then
                    task.wait(0.2)
                    continue
                end
                local tHRP = kHRP(target.Character)
                local tHum = kHum(target.Character)
                if not tHRP or not tHum then task.wait(0.2); continue end

                local myHRP = kHRP(plr.Character)
                if not myHRP then task.wait(0.2); continue end

                local savedMy = myHRP.CFrame
                myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3)
                myHRP.AssemblyLinearVelocity = Vector3.zero

                for _ = 1, 5 do
                    kSno(tHRP)
                    kDestroyLine(tHRP)
                end

                if kOwn(tHRP) then
                    pcall(function()
                        tHum.BreakJointsOnDeath = false
                        tHum:ChangeState(Enum.HumanoidStateType.Dead)
                        tHum.Health = 0
                    end)
                    kResetHRP(tHRP)
                    task.wait(1.2)
                end

                myHRP.CFrame = savedMy
                task.wait(0.05)
            end

            pcall(function() workspace.FallenPartsDestroyHeight = savedFallen or -100 end)
        end)
        KM.activeTasks[handle] = true
        return handle
    end

    -- ---------- mass kick ----------
    local function massTick()
        if not KM.massRunning then return end
        for _, slot in ipairs(KM.massSlots) do
            if slot.player and slot.player.Parent and slot.player.Character and not slot.thread then
                slot.thread = task.spawn(function()
                    while KM.massRunning and slot.player and slot.player.Parent do
                        local char = slot.player.Character
                        local h = kHRP(char)
                        local hum = kHum(char)
                        if not h or not hum or hum.Health <= 0 then break end
                        kSno(h)
                        kDestroyLine(h)
                        kApplyLock(h, hum, CFrame.new(h.Position + Vector3.new(0, 15, 0)))
                        if kOwn(h) then
                            pcall(function()
                                hum.BreakJointsOnDeath = false
                                hum:ChangeState(Enum.HumanoidStateType.Dead)
                                hum.Health = 0
                            end)
                            break
                        end
                        RunService.Heartbeat:Wait()
                    end
                    slot.thread = nil
                end)
            end
        end
    end

    local function massStart()
        KM.massRunning = true
        KM.massThreads = {}
        for _ = 1, 5 do
            table.insert(KM.massThreads, task.spawn(function()
                while KM.massRunning do
                    massTick()
                    task.wait(0.05)
                end
            end))
        end
    end

    local function massStop()
        KM.massRunning = false
        for _, slot in ipairs(KM.massSlots) do
            if slot.thread then pcall(task.cancel, slot.thread) end
            if slot.player and slot.player.Character then
                local h = kHRP(slot.player.Character)
                if h then kResetHRP(h) end
                kResetHum(slot.player.Character)
            end
            slot.thread = nil
        end
        for _, t in ipairs(KM.massThreads) do
            pcall(task.cancel, t)
        end
        KM.massThreads = {}
    end

    -- ---------- stop ----------
    local function stopAll()
        for t in pairs(KM.activeTasks) do
            pcall(task.cancel, t)
        end
        KM.activeTasks = {}
        massStop()
        local target = kTarget()
        if target and target.Character then
            local h = kHRP(target.Character)
            if h then kResetHRP(h) end
            kResetHum(target.Character)
        end
    end

    -- ---------- UI ----------
    KickBox:AddDropdown("KM_TargetDD", {
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
            KM.selected = kNormalize(v)
            SelectedTarget = KM.selected
        end,
    })

    KickBox:AddButton("Refresh Target List", function()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= plr then
                table.insert(t, p.DisplayName .. " (" .. p.Name .. ")")
            end
        end
        Options.KM_TargetDD:SetValues(t)
    end)

    KickBox:AddDropdown("KM_LockModeDD", {
        Text = "Lock Mode",
        Values = { "Standard", "Above", "Circle", "Front" },
        Default = "Standard",
        Multi = false,
        Callback = function(v) KM.lockMode = v end,
    })

    KickBox:AddDivider()
    KickBox:AddLabel("Kicks", true, Color3.fromRGB(255, 150, 50))

    KickBox:AddToggle("KM_TargetKickToggle", {
        Text = "Target Kick (loop)",
        Default = false,
        Callback = function(v)
            if v then
                if not kTarget() then
                    kNotify("Mercury", "Selecione um alvo primeiro", 3)
                    Toggles.KM_TargetKickToggle:SetValue(false)
                    return
                end
                KM.kickTask = startTargetKick(KM.lockMode)
            else
                if KM.kickTask then
                    KM.activeTasks[KM.kickTask] = nil
                    pcall(task.cancel, KM.kickTask)
                    KM.kickTask = nil
                end
            end
        end,
    })

    KickBox:AddToggle("KM_BlobLockToggle", {
        Text = "Blob Lock (trava alvo)",
        Default = false,
        Callback = function(v)
            if v then
                if not kTarget() then
                    kNotify("Mercury", "Selecione um alvo primeiro", 3)
                    Toggles.KM_BlobLockToggle:SetValue(false)
                    return
                end
                KM.lockTask = startBlobLock()
            else
                if KM.lockTask then
                    KM.activeTasks[KM.lockTask] = nil
                    pcall(task.cancel, KM.lockTask)
                    KM.lockTask = nil
                end
            end
        end,
    })

    KickBox:AddToggle("KM_CircleSpinToggle", {
        Text = "Circle Spin (gira alvo)",
        Default = false,
        Callback = function(v)
            if v then
                if not kTarget() then
                    kNotify("Mercury", "Selecione um alvo primeiro", 3)
                    Toggles.KM_CircleSpinToggle:SetValue(false)
                    return
                end
                KM.spinTask = startCircleSpin()
            else
                if KM.spinTask then
                    KM.activeTasks[KM.spinTask] = nil
                    pcall(task.cancel, KM.spinTask)
                    KM.spinTask = nil
                end
            end
        end,
    })

    KickBox:AddToggle("KM_LoopKillToggle", {
        Text = "Loop Kill (ownership)",
        Default = false,
        Callback = function(v)
            if v then
                if not kTarget() then
                    kNotify("Mercury", "Selecione um alvo primeiro", 3)
                    Toggles.KM_LoopKillToggle:SetValue(false)
                    return
                end
                KM.killTask = startLoopKill()
            else
                if KM.killTask then
                    KM.activeTasks[KM.killTask] = nil
                    pcall(task.cancel, KM.killTask)
                    KM.killTask = nil
                end
            end
        end,
    })

    KickBox:AddDivider()
    KickBox:AddLabel("One-Click", true, Color3.fromRGB(255, 150, 50))

    KickBox:AddButton("Bring Target", function()
        local target = kTarget()
        if not target or not target.Character then kNotify("Mercury", "Sem alvo", 3); return end
        local blob = kEnsureBlob()
        if not blob then return end
        local tHRP = kHRP(target.Character)
        if not tHRP then return end
        kGrab(blob, tHRP, "Left")
        task.wait(0.1)
        kGrab(blob, tHRP, "Right")
    end)

    KickBox:AddButton("Kick Once (kill)", function()
        local target = kTarget()
        if not target or not target.Character then kNotify("Mercury", "Sem alvo", 3); return end
        local blob = kEnsureBlob()
        if not blob then return end
        local tHRP = kHRP(target.Character)
        local tHum = kHum(target.Character)
        if not tHRP or not tHum then return end
        for _ = 1, 5 do
            kGrab(blob, tHRP, "Left")
            kGrab(blob, tHRP, "Right")
            kSno(tHRP)
            kDestroyLine(tHRP)
            task.wait(0.02)
        end
        if kOwn(tHRP) then
            pcall(function()
                tHum.BreakJointsOnDeath = false
                tHum:ChangeState(Enum.HumanoidStateType.Dead)
                tHum.Health = 0
            end)
        end
    end)

    KickBox:AddButton("Auto Sit Blobman", function()
        kEnsureBlob()
    end)

    KickBox:AddButton("Reset Blobman", function()
        local b = kFindBlob()
        if b then pcall(function() DestroyToy:FireServer(b) end) end
        local h = kHum(plr.Character)
        if h then h.Sit = false end
        task.wait(0.2)
        kEnsureBlob()
    end)

    KickBox:AddDivider()
    KickBox:AddLabel("Mass Kick", true, Color3.fromRGB(255, 80, 80))

    for i = 1, 5 do
        KickBox:AddDropdown("KM_Mass" .. i, {
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
                    KM.massSlots[i] = nil
                    return
                end
                local name = kNormalize(v)
                local p = name and Players:FindFirstChild(name)
                if p then KM.massSlots[i] = { player = p } end
            end,
        })
    end

    KickBox:AddToggle("KM_MassKickToggle", {
        Text = "Mass Kick (5 slots)",
        Default = false,
        Callback = function(v)
            if v then
                if #KM.massSlots == 0 then
                    kNotify("Mercury", "Selecione pelo menos 1 slot", 3)
                    Toggles.KM_MassKickToggle:SetValue(false)
                    return
                end
                massStart()
            else
                massStop()
            end
        end,
    })

    KickBox:AddDivider()
    KickBox:AddLabel("Utility", true, Color3.fromRGB(0, 200, 100))

    KickBox:AddToggle("KM_AutoSitToggle", {
        Text = "Auto Sit Blobman (contínuo)",
        Default = false,
        Callback = function(v)
            if v then
                KM.autoSitThread = task.spawn(function()
                    while Toggles.KM_AutoSitToggle.Value do
                        kEnsureBlob()
                        task.wait(3)
                    end
                end)
            else
                if KM.autoSitThread then
                    pcall(task.cancel, KM.autoSitThread)
                    KM.autoSitThread = nil
                end
            end
        end,
    })

    KickBox:AddButton("Stop All", function()
        stopAll()
        for _, name in ipairs({ "KM_TargetKickToggle", "KM_BlobLockToggle", "KM_CircleSpinToggle", "KM_LoopKillToggle", "KM_MassKickToggle", "KM_AutoSitToggle" }) do
            if Toggles[name] then Toggles[name]:SetValue(false) end
        end
    end)

    Library:OnUnload(function()
        stopAll()
    end)
end
-- ============================= FIM KICKS MERCURY =============================
