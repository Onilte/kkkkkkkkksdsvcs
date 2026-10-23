do
    local TargetTab = Tabs.Target

    local TPlayers   = game:GetService("Players")
    local TRS        = game:GetService("ReplicatedStorage")
    local TWS        = game:GetService("Workspace")
    local TRun       = game:GetService("RunService")
    local TDebris    = game:GetService("Debris")
    local TLP        = TPlayers.LocalPlayer

    local TGrabEvents  = TRS:WaitForChild("GrabEvents", 10)
    local TSetNetOwner = TGrabEvents and TGrabEvents:WaitForChild("SetNetworkOwner", 10)
    local TDestroyLine = TGrabEvents and TGrabEvents:WaitForChild("DestroyGrabLine", 10)
    local TCreateLine  = TGrabEvents and TGrabEvents:WaitForChild("CreateGrabLine", 10)
    local TCharEvents  = TRS:WaitForChild("CharacterEvents", 10)
    local TStruggle    = TCharEvents and TCharEvents:WaitForChild("Struggle", 10)
    local TMenuToys    = TRS:WaitForChild("MenuToys", 10)
    local TSpawnToy    = TMenuToys and TMenuToys:WaitForChild("SpawnToyRemoteFunction", 10)
    local TDestroyToy  = TMenuToys and TMenuToys:WaitForChild("DestroyToy", 10)

--/(state)
    local TSelected        = {}
    local TSelectedOrder   = {}
    local TCleanups        = {}
    local TAllThreads      = {}
    local TAllConnections  = {}
    local TPreviousTargets = {}
    local TPendingRejoin   = {}
    local TKickTargets     = {}

    local LoopPlayer = false
    local LoopServer = false
    local LoopSnowballActive = false
    local LoopSnowballThread = nil
    local LoopRagdollActive = false
    local LoopRagdollThread = nil
    local RagdollPallet = nil
    local RagdollSoundPart = nil
    local UnstickAuraActive = false
    local UnstickAuraThread = nil
    local UnstickRadius = 20
    local SelectedMethods = {}
    local MethodOrder = {}
    local kickOffsetX, kickOffsetY, kickOffsetZ = 0, 20, 0
    local LineLagActive = false
    local currentLineLagPower = 500

    local OwnershipKickActive = {}
    local OwnershipKickThread = {}
    local OwnershipKickRefs   = {}
    local OwnershipKickPallet = {}
    local LastBurstTime       = {}
    local selectedOwnershipMode = "Ownership kick (Strong)"

    local StrongAntiLine      = true
    local StrongRagdollReset  = true

--/(helpers)
    local function TAddCleanup(fn) table.insert(TCleanups, fn) end
    local function TRegisterThread(t) TAllThreads[t] = true end
    local function TRegisterConn(c) TAllConnections[c] = true end

    local function TNotify(desc, duration, icon)
        Library:Notify({
            Title = "Echo",
            Description = desc or "",
            Time = duration or 3,
            Icon = icon or "bell",
        })
    end

    local function TGetFormattedName(player)
        if not player then return "Unknown" end
        return tostring(player.DisplayName or player.Name) .. " (@" .. tostring(player.Name) .. ")"
    end

    local function TBuildNameList()
        local list = {}
        for _, p in ipairs(TPlayers:GetPlayers()) do
            if p ~= TLP then table.insert(list, TGetFormattedName(p)) end
        end
        table.sort(list)
        return list
    end

    local function TGetPlayerFromEntry(entry)
        if type(entry) ~= "string" then return nil end
        local username = entry:match("%(@([%w_]+)%)")
        return username and TPlayers:FindFirstChild(username) or nil
    end

    local function TAddSelected(plr)
        if not plr or plr == TLP then return end
        if TSelected[plr.Name] then return end
        TSelected[plr.Name] = plr
        table.insert(TSelectedOrder, plr.Name)
        TPreviousTargets[plr.Name] = true
    end

    local function TRemoveSelected(name)
        TSelected[name] = nil
        TPreviousTargets[name] = nil
        for i, n in ipairs(TSelectedOrder) do
            if n == name then table.remove(TSelectedOrder, i) break end
        end
    end

    local function TClearSelected()
        for name in pairs(TSelected) do
            TPreviousTargets[name] = nil
        end
        TSelected = {}
        TSelectedOrder = {}
    end

    local function TGetSelectedList()
        local list = {}
        for _, name in ipairs(TSelectedOrder) do
            local p = TPlayers:FindFirstChild(name)
            if p and p.Parent then table.insert(list, p) end
        end
        return list
    end

    local function TGetMyHRP()
        local c = TLP.Character
        return c and c:FindFirstChild("HumanoidRootPart") or nil
    end

    local function makeAnchorGetter(idx, total)
        return function()
            local hrp = TGetMyHRP()
            local basePos = hrp and hrp.Position or Vector3.new(0, 0, 0)
            local offsetAngle = (idx - 1) * (math.pi * 2 / math.max(total, 1))
            local offsetRadius = 6 + math.floor((idx - 1) / 8) * 4
            return basePos + Vector3.new(
                math.cos(offsetAngle) * offsetRadius + kickOffsetX,
                kickOffsetY + math.floor((idx - 1) / 4) * 5,
                math.sin(offsetAngle) * offsetRadius + kickOffsetZ
            )
        end
    end

    local function TMethodSelected(name)
        return SelectedMethods[name] == true
    end

    local function TKillAllThreads()
        for thread in pairs(TAllThreads) do
            pcall(function() task.cancel(thread) end)
            TAllThreads[thread] = nil
        end
    end

    local function TDisconnectAll()
        for conn in pairs(TAllConnections) do
            pcall(function() conn:Disconnect() end)
            TAllConnections[conn] = nil
        end
    end

--/(fps)
    local SharedFPS = 60
    local fpsFrames, fpsAccum = 0, 0
    TRegisterConn(TRun.Heartbeat:Connect(function(dt)
        fpsFrames += 1
        fpsAccum += dt
        if fpsAccum >= 0.5 then
            SharedFPS = math.floor((fpsFrames / fpsAccum) + 0.5)
            fpsFrames, fpsAccum = 0, 0
        end
    end))

--/(ownership helpers)
    local function OK_NukeForeignWelds(char)
        if not char or not char.Parent then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        for _, d in ipairs(hrp:GetChildren()) do
            if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
                local p0, p1 = d.Part0, d.Part1
                if p0 and p1 and not (p0:IsDescendantOf(char) and p1:IsDescendantOf(char)) then
                    pcall(function() d:Destroy() end)
                end
            end
        end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("WeldConstraint") or d:IsA("Weld") then
                local p0, p1 = d.Part0, d.Part1
                if p0 and p1 and not (p0:IsDescendantOf(char) and p1:IsDescendantOf(char)) then
                    pcall(function() d:Destroy() end)
                end
            elseif d:IsA("BodyPosition") or d:IsA("BodyGyro")
                or d:IsA("BodyVelocity") or d:IsA("BodyAngularVelocity")
                or d:IsA("VectorForce") or d:IsA("LinearVelocity")
                or d:IsA("AngularVelocity") or d:IsA("AlignPosition")
                or d:IsA("AlignOrientation") then
                local nm = d.Name
                if not nm:find("EchoKick") then
                    local p = d.Parent
                    if p == hrp or (p and p:IsDescendantOf(char)) then
                        pcall(function() d:Destroy() end)
                    end
                end
            end
        end
    end

    local function OK_FindPCLD(target)
        if not target then return nil end
        local char = target.Character
        if not char then return nil end
        for _, c in ipairs(char:GetChildren()) do
            if c.Name == "PlayerCharacterLocationDetector" and c:IsA("BasePart") then
                return c
            end
        end
        for _, c in ipairs(char:GetDescendants()) do
            if c.Name == "PlayerCharacterLocationDetector" and c:IsA("BasePart") then
                return c
            end
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local best, bestD = nil, 5
            for _, c in ipairs(TWS:GetChildren()) do
                if c.Name == "PlayerCharacterLocationDetector" and c:IsA("BasePart") then
                    local d = (c.Position - hrp.Position).Magnitude
                    if d < bestD then best, bestD = c, d end
                end
            end
            if best then return best end
        end
        return nil
    end

    local function OK_WeOwnIt(part)
        if not part or not part.Parent then return false end
        local po = part:FindFirstChild("PartOwner")
        if po and po:IsA("StringValue") then
            local ok, v = pcall(function() return po.Value end)
            return ok and v == TLP.Name
        end
        return false
    end

    local RemoteBudget = { MaxPerSec = 220, Window = {} }

    local function RemoteBudget_Take(n)
        n = n or 1
        local now = tick()
        for i = #RemoteBudget.Window, 1, -1 do
            if now - RemoteBudget.Window[i].t > 1.0 then
                table.remove(RemoteBudget.Window, i)
            else
                break
            end
        end
        local used = 0
        for _, e in ipairs(RemoteBudget.Window) do used = used + e.n end
        local remaining = RemoteBudget.MaxPerSec - used
        if remaining <= 0 then return 0 end
        local allowed = math.min(n, remaining)
        table.insert(RemoteBudget.Window, {t = now, n = allowed})
        return allowed
    end

--/(fps-adaptive spam helpers)
    local function StrongGetSpamCount()
        local fps = SharedFPS
        if fps > 240 then return 6
        elseif fps > 200 then return 5
        elseif fps > 155 then return 4
        elseif fps > 120 then return 3
        else return 2 end
    end

    local function StrongGetSpamInterval()
        local fps = SharedFPS
        if fps > 240 then return 0.015
        elseif fps > 200 then return 0.02
        elseif fps > 155 then return 0.025
        elseif fps > 120 then return 0.03
        else return 0.04 end
    end

    local function StrongGetBalancedCount()
        local fps = SharedFPS
        if fps > 200 then return 4
        elseif fps > 155 then return 3
        elseif fps > 120 then return 2
        else return 1 end
    end

    local function StrongGetBalancedInterval()
        local fps = SharedFPS
        if fps > 200 then return 0.025
        elseif fps > 155 then return 0.03
        elseif fps > 120 then return 0.04
        else return 0.05 end
    end

    local function StrongGetFastCount()
        local fps = SharedFPS
        if fps > 200 then return 2
        elseif fps > 155 then return 2
        else return 1 end
    end

    local function StrongGetFastInterval()
        local fps = SharedFPS
        if fps > 200 then return 0.03
        elseif fps > 155 then return 0.04
        else return 0.05 end
    end

    local cfgByMode = {
        ["Ownership kick (fast)"]     = {
            ackTimeout = 0.30, grabWindow = 0.15, maxDist = 12,
            escapeRecover = false, inRange = 25,
            anchorOffset = CFrame.new(0, 20, 0),
            burstCooldown = 0.03,
            getFires = StrongGetFastCount,
            getInterval = StrongGetFastInterval,
        },
        ["Ownership kick (balanced)"] = {
            ackTimeout = 0.60, grabWindow = 0.28, maxDist = 16,
            escapeRecover = true, inRange = 25,
            anchorOffset = CFrame.new(0, 20, 0),
            burstCooldown = 0.05,
            getFires = StrongGetBalancedCount,
            getInterval = StrongGetBalancedInterval,
        },
        ["Ownership kick (Strong)"]   = {
            ackTimeout = 0.70, grabWindow = 0.35, maxDist = 10,
            escapeRecover = true, inRange = 25,
            anchorOffset = CFrame.new(0, 20, 0),
            burstCooldown = 0.02,
            getFires = StrongGetSpamCount,
            getInterval = StrongGetSpamInterval,
        },
    }

    local function OK_FiresFor(mode)
        local cfg = cfgByMode[mode] or cfgByMode["Ownership kick (Strong)"]
        return cfg.getFires()
    end

--/(ownership pallet)
    local function CleanupPalletFor(name)
        local ref = OwnershipKickPallet[name]
        if not ref then return end
        pcall(function()
            if ref.pallet and ref.pallet.Parent and TDestroyToy then
                TDestroyToy:FireServer(ref.pallet)
            end
        end)
        OwnershipKickPallet[name] = nil
    end

    local function CleanupBodiesFor(name)
        LastBurstTime[name] = nil
        OwnershipKickRefs[name] = nil
    end

    local function TStopOwnershipKickForPlayer(name)
        OwnershipKickActive[name] = false
        CleanupBodiesFor(name)
        CleanupPalletFor(name)
        OwnershipKickThread[name] = nil
    end

    local function TStopAllOwnershipKicks()
        local names = {}
        for name in pairs(OwnershipKickActive) do
            table.insert(names, name)
        end
        for _, name in ipairs(names) do
            TStopOwnershipKickForPlayer(name)
        end
        OwnershipKickActive = {}
        OwnershipKickThread = {}
        OwnershipKickRefs = {}
        OwnershipKickPallet = {}
        LastBurstTime = {}
    end

--/(ownership core)
    local function RunOwnershipKick(targetName, keepGoing, anchorGetter)
        local myChar = TLP.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local savedPos      = myRoot.CFrame
        local savedAnchored = myRoot.Anchored

        local mode = selectedOwnershipMode
        local cfg = cfgByMode[mode] or cfgByMode["Ownership kick (Strong)"]

        local grabStartTime  = 0
        local dragging       = false
        local checkStartTime = 0
        local ownedRoot      = nil

        while keepGoing() do
            myChar = TLP.Character
            myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myRoot then break end

            myRoot.AssemblyLinearVelocity  = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero

            OK_NukeForeignWelds(myChar)

            local target = TPlayers:FindFirstChild(targetName)
            if not target or not target.Parent then break end

            local tChar = target.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum  = tChar and tChar:FindFirstChildOfClass("Humanoid")

            if not (tRoot and tHum) or tHum.Health <= 0 then
                ownedRoot  = nil
                dragging   = false
                grabStartTime = 0
                checkStartTime = 0
                TRun.Heartbeat:Wait()
                continue
            end

            OK_NukeForeignWelds(tChar)

            local distToVictim = (myRoot.Position - tRoot.Position).Magnitude

            local baseAnchor
            if type(anchorGetter) == "function" then
                baseAnchor = anchorGetter() or tRoot.Position
            elseif typeof(anchorGetter) == "Vector3" then
                baseAnchor = anchorGetter
            else
                baseAnchor = tRoot.Position
            end

            if not dragging then
                local pcl  = OK_FindPCLD(target)
                local head = tChar:FindFirstChild("Head")

                if distToVictim > cfg.inRange then
                    pcall(function()
                        local dir = (tRoot.Position - myRoot.Position)
                        if dir.Magnitude > 0 then dir = dir.Unit end
                        myRoot.CFrame = CFrame.new(tRoot.Position - dir * 3, tRoot.Position)
                        myRoot.AssemblyLinearVelocity  = Vector3.zero
                        myRoot.AssemblyAngularVelocity = Vector3.zero
                    end)
                else
                    pcall(function()
                        myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
                        myRoot.AssemblyLinearVelocity  = Vector3.zero
                        myRoot.AssemblyAngularVelocity = Vector3.zero
                    end)
                end

                local ackDeadline = tick() + cfg.ackTimeout
                local acked = false

                while tick() < ackDeadline do
                    local allow = RemoteBudget_Take(1)
                    if allow > 0 then
                        pcall(function()
                            TSetNetOwner:FireServer(tRoot, tRoot.CFrame)
                            if head then TSetNetOwner:FireServer(head, head.CFrame) end
                            if pcl then TSetNetOwner:FireServer(pcl, pcl.CFrame) end
                            TDestroyLine:FireServer(tRoot)
                        end)
                    end

                    if OK_WeOwnIt(tRoot) or OK_WeOwnIt(head) then
                        acked = true
                        break
                    end
                    TRun.Heartbeat:Wait()
                end

                if acked then
                    dragging = true
                    grabStartTime = 0
                    checkStartTime = tick()
                    ownedRoot = tRoot

                    if tHum.PlatformStand ~= true then tHum.PlatformStand = true end
                    if tHum.Sit          ~= true then tHum.Sit          = true end

                    tRoot.CFrame = CFrame.new(baseAnchor) * tRoot.CFrame.Rotation
                    tRoot.AssemblyLinearVelocity  = Vector3.zero
                    tRoot.AssemblyAngularVelocity = Vector3.zero

                    pcall(function() if TStruggle then TStruggle:FireServer(TLP) end end)
                else
                    if grabStartTime == 0 then grabStartTime = tick() end
                    if tick() - grabStartTime > cfg.grabWindow then
                        grabStartTime = 0
                    end
                end
            else
                -- LOCKED PHASE
                if tHum.PlatformStand ~= true then tHum.PlatformStand = true end
                if tHum.Sit          ~= true then tHum.Sit          = true end

                local now = tick()
                local spamInterval = cfg.getInterval()
                if not LastBurstTime[targetName] or now - LastBurstTime[targetName] >= spamInterval then
                    LastBurstTime[targetName] = now

                    local head = tChar:FindFirstChild("Head")
                    local pcl  = OK_FindPCLD(target)

                    local wantRoot = not OK_WeOwnIt(tRoot)
                    local wantHead = head and not OK_WeOwnIt(head)
                    local wantPcl  = pcl  and not OK_WeOwnIt(pcl)

                    if wantRoot then
                        local allow = RemoteBudget_Take(1)
                        if allow > 0 then
                            pcall(function()
                                TSetNetOwner:FireServer(tRoot, tRoot.CFrame)
                            end)
                        end
                    end
                    if wantHead then
                        local allow = RemoteBudget_Take(1)
                        if allow > 0 then
                            pcall(function()
                                TSetNetOwner:FireServer(head, head.CFrame)
                            end)
                        end
                    end
                    if wantPcl then
                        local allow = RemoteBudget_Take(1)
                        if allow > 0 then
                            pcall(function()
                                TSetNetOwner:FireServer(pcl, pcl.CFrame)
                            end)
                        end
                    end

                    if StrongAntiLine then
                        pcall(function()
                            TDestroyLine:FireServer(tRoot)
                            if head then TDestroyLine:FireServer(head) end
                        end)
                    end
                end

                pcall(function()
                    tRoot.CFrame = CFrame.new(baseAnchor) * tRoot.CFrame.Rotation
                    tRoot.AssemblyLinearVelocity  = Vector3.zero
                    tRoot.AssemblyAngularVelocity = Vector3.zero
                end)

                if StrongRagdollReset then
                    pcall(function()
                        local rr = TCharEvents and TCharEvents:FindFirstChild("RagdollRemote")
                        if rr then rr:FireServer(tRoot, 0) end
                    end)
                end

                if cfg.escapeRecover and checkStartTime > 0 and tick() - checkStartTime > 0.30 then
                    if (tRoot.Position - baseAnchor).Magnitude > cfg.maxDist then
                        dragging = false
                        grabStartTime = 0
                        checkStartTime = 0
                        ownedRoot = nil
                    else
                        checkStartTime = tick()
                    end
                end
            end

            TRun.Heartbeat:Wait()
        end

        pcall(function()
            local target = TPlayers:FindFirstChild(targetName)
            local tChar = target and target.Character
            local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
            if tHum then
                tHum.PlatformStand = false
                tHum.Sit = false
            end
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            if tRoot then
                tRoot.Anchored = false
                tRoot.AssemblyLinearVelocity  = Vector3.zero
                tRoot.AssemblyAngularVelocity = Vector3.zero
            end
        end)

        pcall(function()
            if myRoot and myRoot.Parent then
                myRoot.Anchored = savedAnchored or false
                myRoot.CFrame   = savedPos
                myRoot.AssemblyLinearVelocity  = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end
        end)
    end

--/(reset)
    local function TResetAll()
        TStopAllOwnershipKicks()
        LoopSnowballActive = false
        LoopRagdollActive = false
        UnstickAuraActive = false
        LoopPlayer = false
        LoopServer = false
        LineLagActive = false
        TKillAllThreads()
        pcall(function()
            if Library.Toggles.EchoLoopSnowball then Library.Toggles.EchoLoopSnowball:SetValue(false) end
            if Library.Toggles.EchoLoopRagdoll then Library.Toggles.EchoLoopRagdoll:SetValue(false) end
            if Library.Toggles.EchoRemoveAntiStickyAura then Library.Toggles.EchoRemoveAntiStickyAura:SetValue(false) end
            if Library.Toggles.EchoLoopPlayer then Library.Toggles.EchoLoopPlayer:SetValue(false) end
            if Library.Toggles.EchoLoopServer then Library.Toggles.EchoLoopServer:SetValue(false) end
        end)
    end

    TRegisterConn(TLP.CharacterAdded:Connect(function()
        task.wait(0.5)
        TResetAll()
    end))

--/(join/leave notifications)
    local TotalKicks = 0

    local function TKickNotification(kickedPlayer, kickerName)
        local display = kickedPlayer and (kickedPlayer.DisplayName or kickedPlayer.Name) or "Unknown"
        local user    = kickedPlayer and kickedPlayer.Name or "Unknown"
        local kicker  = kickerName or TLP.DisplayName or TLP.Name
        local desc = string.format(
            "%s (@%s) has been kicked by %s\nTotal Kicks: %d",
            display, user, kicker, TotalKicks
        )
        Library:Notify({
            Title = "Echo",
            Icon  = "bell",
            Description = desc,
            Time = 5,
        })
    end

    TRegisterConn(TPlayers.PlayerAdded:Connect(function(player)
        task.defer(function()
            if TPendingRejoin[player.UserId] then
                TPendingRejoin[player.UserId] = nil
                TNotify("Target " .. TGetFormattedName(player) .. " Has rejoined the server.", 4, "bell")
                return
            end
            local isFriend = false
            pcall(function() isFriend = TLP:IsFriendsWith(player.UserId) end)
            if isFriend then
                TNotify("Your friend " .. TGetFormattedName(player) .. " Has Joined the server.", 4, "bell")
            else
                TNotify(TGetFormattedName(player) .. " Has Joined the server.", 4, "bell")
            end
        end)
    end))

    TRegisterConn(TPlayers.PlayerRemoving:Connect(function(player)
        local wasTarget = TPreviousTargets[player.Name] == true
        local wasKickTarget = TKickTargets[player.UserId] == true
        if wasTarget then TPendingRejoin[player.UserId] = true end
        if wasKickTarget then
            TKickTargets[player.UserId] = nil
            TotalKicks += 1
            TKickNotification(player, TLP.DisplayName or TLP.Name)
        else
            TNotify(TGetFormattedName(player) .. " Has left the server.", 4, "bell")
        end
    end))

--/(ui)
    local TargetGroup  = TargetTab:AddLeftGroupbox("Target", "crosshair")
    local LoopsGroup   = TargetTab:AddLeftGroupbox("Loops", "repeat")
    local MethodsGroup = TargetTab:AddRightGroupbox("Methods", "swords")

    local TTargetDropdown

    local function TGetDropdownValueMap()
        local current = {}
        for name in pairs(TSelected) do
            local p = TPlayers:FindFirstChild(name)
            if p then current[TGetFormattedName(p)] = true end
        end
        return current
    end

    TTargetDropdown = TargetGroup:AddDropdown("EchoTargetDropdown", {
        Text = "Select Targets",
        Values = TBuildNameList(),
        Default = {},
        AllowNull = true,
        Searchable = true,
        Multi = true,
        ExcludeLocalPlayer = true,
        SpecialType = "Player",
        EnablePlayerImages = true,
        FormatListValue = function(plr)
            if typeof(plr) == "Instance" and plr:IsA("Player") then
                return string.format("%s (@%s)", plr.DisplayName, plr.Name)
            end
            return tostring(plr)
        end,
        Callback = function(val)
            TClearSelected()
            if type(val) ~= "table" then return end
            for k, v in pairs(val) do
                if v then
                    local plr = nil
                    if typeof(k) == "Instance" and k:IsA("Player") then
                        plr = k
                    elseif type(k) == "string" then
                        plr = TGetPlayerFromEntry(k)
                    end
                    if not plr and typeof(v) == "Instance" and v:IsA("Player") then
                        plr = v
                    end
                    if plr and plr.Parent then TAddSelected(plr) end
                end
            end
        end,
    })

    local function TSyncDropdownFromSelection()
        pcall(function() TTargetDropdown:SetValue(TGetDropdownValueMap()) end)
    end

    TargetGroup:AddButton({
        Text = "Refresh List",
        Tooltip = "Manually refresh the target player list",
        Func = function()
            local newList = TBuildNameList()
            pcall(function() TTargetDropdown:SetValues(newList) end)
            local toRemove = {}
            for name, plr in pairs(TSelected) do
                if not plr or not plr.Parent then
                    table.insert(toRemove, name)
                end
            end
            for _, name in ipairs(toRemove) do
                TRemoveSelected(name)
            end
            TSyncDropdownFromSelection()
            TNotify("Target list refreshed", 2, "refresh-cw")
        end,
    })

    TargetGroup:AddButton({
        Text = "Clear Targets",
        Func = function()
            TClearSelected()
            pcall(function() TTargetDropdown:SetValue({}) end)
            TNotify("Targets cleared", 2, "x")
        end,
    })

--/(select by look)
    local function TGetPlayerFromLook()
        local char = TLP.Character
        if not char then return nil end
        local camera = TWS.CurrentCamera
        if not camera then return nil end
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = { char }
        params.FilterType = Enum.RaycastFilterType.Exclude
        local result = TWS:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 1000, params)
        if result then
            local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
            if hitModel then return TPlayers:GetPlayerFromCharacter(hitModel) end
        end
        return nil
    end

    TargetGroup:AddLabel("Select Target"):AddKeyPicker("EchoSelectTargetKey", {
        Text = "Select by Look",
        Default = "None",
        Mode = "Press",
        Callback = function()
            local player = TGetPlayerFromLook()
            if not player or player == TLP then
                TNotify("No player in view", 2, "alert-triangle")
                return
            end
            local formatted = TGetFormattedName(player)
            TAddSelected(player)
            TSyncDropdownFromSelection()
            TNotify("Selected " .. formatted, 2, "user-plus")
        end,
    })

    TPlayers.PlayerRemoving:Connect(function(plr)
        if TSelected[plr.Name] then
            TRemoveSelected(plr.Name)
            TSyncDropdownFromSelection()
        end
    end)

--/(forward decls)
    local TStartOwnershipKickForPlayer
    local TApplyToPlayer
    local KickGroup
    local TStartLoopSnowball, TStopLoopSnowball
    local TStartLoopRagdoll, TStopLoopRagdoll
    local TStartUnstickAura, TStopUnstickAura

    LoopsGroup:AddToggle("EchoLoopPlayer", {
        Text = "Loop Apply Method",
        Default = false,
        Callback = function(v)
            LoopPlayer = v
            if v then
                local count = 0
                for _ in pairs(TSelected) do count = count + 1 end
                if count == 0 then
                    TNotify("Select a target first", 3, "alert-triangle")
                    Library.Toggles.EchoLoopPlayer:SetValue(false)
                    LoopPlayer = false
                end
            else
                TStopAllOwnershipKicks()
            end
        end,
    })

    LoopsGroup:AddToggle("EchoLoopServer", {
        Text = "Loop Apply Method Server",
        Default = false,
        Callback = function(v)
            LoopServer = v
            if not v then
                TStopAllOwnershipKicks()
            end
        end,
    })

    LoopsGroup:AddButton({
        Text = "Apply Method Once",
        Func = function()
            local targets = TGetSelectedList()
            if #targets == 0 then
                TNotify("Select a target first", 3, "alert-triangle")
                return
            end
            for i, plr in ipairs(targets) do
                local getAnchor = makeAnchorGetter(i, #targets)
                task.spawn(function()
                    if TMethodSelected("Kick") then
                        TStartOwnershipKickForPlayer(plr, getAnchor)
                    end
                    TApplyToPlayer(plr, getAnchor())
                end)
            end
        end,
    })

    LoopsGroup:AddButton({
        Text = "Apply Method Server Once",
        Func = function()
            local targets = {}
            for _, plr in ipairs(TPlayers:GetPlayers()) do
                if plr ~= TLP and plr.Character then table.insert(targets, plr) end
            end
            if #targets == 0 then
                TNotify("No targets on server", 3, "alert-triangle")
                return
            end
            TNotify("Server kick on " .. #targets .. " players", 2, "play")
            task.spawn(function()
                local baseHRP = TGetMyHRP()
                local basePos = baseHRP and baseHRP.Position or Vector3.new(0, 0, 0)
                LineLagActive = true
                local lineLagConn
                local lastLineBurst = 0
                local LINE_BURST_INTERVAL = 0.15
                local LINE_BURST_MAX = 3
                lineLagConn = TRun.Heartbeat:Connect(function()
                    if not LineLagActive then
                        if lineLagConn then lineLagConn:Disconnect() end
                        return
                    end
                    local now = tick()
                    if now - lastLineBurst < LINE_BURST_INTERVAL then return end
                    lastLineBurst = now
                    local spawnLocation = TWS:FindFirstChild("SpawnLocation")
                        or TWS:FindFirstChild("Spawn") or baseHRP
                    if spawnLocation and TCreateLine then
                        local randomX = math.random(-1e9, 1e9)
                        local randomZ = math.random(-1e9, 1e9)
                        local burst = math.clamp(math.floor(currentLineLagPower / 100), 1, LINE_BURST_MAX)
                        for _ = 1, burst do
                            pcall(function()
                                TCreateLine:FireServer(spawnLocation, CFrame.new(randomX, 0, randomZ))
                            end)
                        end
                    end
                end)
                task.wait(0.5)
                for i, plr in ipairs(targets) do
                    if not LineLagActive then break end
                    local getAnchor = makeAnchorGetter(i, #targets)
                    task.spawn(function()
                        if TMethodSelected("Kick") then
                            TStartOwnershipKickForPlayer(plr, getAnchor)
                        end
                        TApplyToPlayer(plr, getAnchor())
                    end)
                    task.wait(0.15)
                end
                LineLagActive = false
                if lineLagConn then lineLagConn:Disconnect() end
                task.wait(2)
                TNotify("Server kick complete", 2, "check")
            end)
        end,
    })

--/(kick group)
    KickGroup = TargetTab:AddRightGroupbox("Ownership Kick Methods", "crosshair")
    pcall(function() KickGroup:SetVisible(false) end)

--/(method selection)
    MethodsGroup:AddDropdown("EchoTargetMethod", {
        Text = "Method Selection",
        Values = { "Kick", "Void", "Kill", "Bring", "Destroy Food", "Remove Gucci", "Remove Invisibility" },
        Default = {},
        Multi = true,
        Callback = function(val)
            SelectedMethods = {}
            MethodOrder = {}
            if type(val) == "table" then
                for k, v in pairs(val) do
                    local name = nil
                    if type(k) == "string" and v then name = k
                    elseif type(v) == "string" then name = v end
                    if name then
                        SelectedMethods[name] = true
                        table.insert(MethodOrder, name)
                    end
                end
            end
            if KickGroup then KickGroup:SetVisible(TMethodSelected("Kick")) end
        end,
    })

    KickGroup:AddDropdown("EchoOwnershipMode", {
        Text = "Ownership Method",
        Values = {
            "Ownership kick (fast)",
            "Ownership kick (balanced)",
            "Ownership kick (Strong)",
        },
        Default = "Ownership kick (Strong)",
        Multi = false,
        Callback = function(v) selectedOwnershipMode = v end,
    })

    KickGroup:AddToggle("EchoLoopSnowball", {
        Text = "Loop Snowball", Default = false,
        Callback = function(v) if v then TStartLoopSnowball() else TStopLoopSnowball() end end,
    })
    KickGroup:AddToggle("EchoLoopRagdoll", {
        Text = "Loop Ragdoll", Default = false,
        Callback = function(v) if v then TStartLoopRagdoll() else TStopLoopRagdoll() end end,
    })
    KickGroup:AddToggle("EchoRemoveAntiStickyAura", {
        Text = "Remove Anti Sticky Aura", Default = false,
        Callback = function(v) if v then TStartUnstickAura() else TStopUnstickAura() end end,
    })

    KickGroup:AddToggle("EchoStrongLayer5", {
        Text = "Layer 5: Anti Grab Line",
        Default = true,
        Tooltip = "Clears grab lines automatically.",
        Callback = function(v) StrongAntiLine = v end,
    })
    KickGroup:AddToggle("EchoStrongLayer4", {
        Text = "Layer 4: Ragdoll Reset",
        Default = true,
        Tooltip = "Resets ragdoll state automatically.",
        Callback = function(v) StrongRagdollReset = v end,
    })

    KickGroup:AddSlider("EchoKickOffsetX", {
        Text = "Kick Offset X", Default = 0, Min = -50, Max = 50, Rounding = 0, Compact = true,
        Callback = function(v) kickOffsetX = v end,
    })
    KickGroup:AddSlider("EchoKickOffsetY", {
        Text = "Kick Offset Y", Default = 20, Min = -50, Max = 100, Rounding = 0, Compact = true,
        Callback = function(v) kickOffsetY = v end,
    })
    KickGroup:AddSlider("EchoKickOffsetZ", {
        Text = "Kick Offset Z", Default = 0, Min = -50, Max = 50, Rounding = 0, Compact = true,
        Callback = function(v) kickOffsetZ = v end,
    })

--/(secondary methods)
    local function TVoidTarget(targetName)
        local target = TPlayers:FindFirstChild(targetName)
        if not target then return end
        local tChar = target.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum  = tChar and tChar:FindFirstChildOfClass("Humanoid")
        if not (tRoot and tHum) then return end
        pcall(function()
            OK_NukeForeignWelds(tChar)
            TSetNetOwner:FireServer(tRoot, tRoot.CFrame)
            TDestroyLine:FireServer(tRoot)
            tRoot.Anchored = false
            tRoot.CFrame = CFrame.new(tRoot.Position.X, -99999, tRoot.Position.Z)
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(0, -9e9, 0)
            bv.MaxForce = Vector3.one * math.huge
            bv.Parent = tRoot
            TDebris:AddItem(bv, 0.5)
        end)
    end

    local function TKillTarget(targetName)
        local target = TPlayers:FindFirstChild(targetName)
        if not target then return end
        local tChar = target.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local tHum  = tChar and tChar:FindFirstChildOfClass("Humanoid")
        if not (tRoot and tHum) or tHum.Health <= 0 then return end
        pcall(function()
            TSetNetOwner:FireServer(tRoot, tRoot.CFrame)
            TDestroyLine:FireServer(tRoot)
            tHum.Sit = false
            tHum:ChangeState(Enum.HumanoidStateType.Running)
            tHum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
            tHum:ChangeState(Enum.HumanoidStateType.GettingUp)
            local rag = tHum:FindFirstChild("Ragdolled")
            if rag then rag.Value = false end
            local bv = Instance.new("BodyVelocity")
            local bav = Instance.new("BodyAngularVelocity")
            bv.MaxForce = Vector3.new(1e7, -1e7, 1e7); bv.P = 1e6
            bv.Velocity = Vector3.new(math.random(-500, 50), -50, math.random(-50, 50))
            bav.MaxTorque = Vector3.new(-1e7, -1e7, -1e7); bav.P = 1e6
            bav.AngularVelocity = Vector3.new(math.random(-500, 300), math.random(-300, 300), math.random(-500, 500))
            bv.Parent = tRoot; bav.Parent = tRoot
            tHum.BreakJointsOnDeath = false
            tHum:ChangeState(Enum.HumanoidStateType.Dead)
            TDebris:AddItem(bv, 2); TDebris:AddItem(bav, 2)
        end)
    end

    local function TBringTarget(targetName)
        local target = TPlayers:FindFirstChild(targetName)
        if not target or not target.Character then return end
        local targetHead = target.Character:FindFirstChild("Head")
        local myRoot = TGetMyHRP()
        if not (targetHead and myRoot) then return end
        local oldCFrame = myRoot.CFrame
        for _ = 1, 2 do
            if not targetHead.Parent then break end
            myRoot.CFrame = targetHead.CFrame * CFrame.new(2, 0, 0)
            pcall(function() TSetNetOwner:FireServer(targetHead, myRoot.CFrame) end)
            task.wait(0.15)
        end
        myRoot.CFrame = oldCFrame
        local front = oldCFrame.LookVector * 5
        pcall(function()
            targetHead.CFrame = CFrame.new(oldCFrame.Position + front)
            TDestroyLine:FireServer(targetHead)
        end)
    end

    local function TDestroyFood(targetName)
        local target = TPlayers:FindFirstChild(targetName)
        if not target then return end
        local inv = TWS:FindFirstChild(target.Name .. "SpawnedInToys")
        if not inv then return end
        for _, item in ipairs(inv:GetChildren()) do
            if item:IsA("Model") and item:FindFirstChild("HoldPart") then
                pcall(function() TDestroyToy:FireServer(item) end)
            end
        end
    end

    local function TRemoveGucci(targetName)
        local VOID_DIST = 500000
        local GRAB_TIME = 0.6

        local function RG_TakeOwnership(part)
            if not part or not part.Parent then return false end
            pcall(function() TSetNetOwner:FireServer(part, part.CFrame) end)
            TRun.Heartbeat:Wait()
            return OK_WeOwnIt(part)
        end

        local function RG_FindSeatables(alvo)
            local out = {}
            local seen = {}
            local function add(s)
                if s and s:IsA("BasePart") and not seen[s] then
                    seen[s] = true
                    out[#out + 1] = s
                end
            end
            local folder = TWS:FindFirstChild(alvo.Name .. "SpawnedInToys")
            if folder then
                for _, obj in ipairs(folder:GetDescendants()) do
                    if obj:IsA("VehicleSeat") or obj:IsA("Seat") then add(obj) end
                end
                for _, obj in ipairs(folder:GetChildren()) do
                    if obj:IsA("Model")
                        and not obj:FindFirstChildWhichIsA("VehicleSeat", true)
                        and not obj:FindFirstChildWhichIsA("Seat", true) then
                        add(obj.PrimaryPart
                            or obj:FindFirstChild("SoundPart", true)
                            or obj:FindFirstChildWhichIsA("BasePart", true))
                    end
                end
            end
            local c = alvo.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h and h.SeatPart then add(h.SeatPart) end
            for _, obj in ipairs(TWS:GetDescendants()) do
                if obj:IsA("VehicleSeat") or obj:IsA("Seat") then
                    local owner = obj:FindFirstChild("PartOwner", true)
                    if owner and owner:IsA("StringValue") and owner.Value == alvo.Name then
                        add(obj)
                    end
                end
            end
            return out
        end

        local function RG_VoidSeatable(seat)
            if not seat or not seat.Parent then return end
            local owns = false
            for _ = 1, 3 do
                if RG_TakeOwnership(seat) then owns = true break end
            end
            if not owns then return end
            pcall(function()
                seat.CFrame = CFrame.new(seat.Position.X, -VOID_DIST, seat.Position.Z)
                seat.AssemblyLinearVelocity = Vector3.new(0, -VOID_DIST, 0)
                seat.AssemblyAngularVelocity = Vector3.zero
            end)
            local stopAt = tick() + 0.35
            while tick() < stopAt and seat.Parent do
                pcall(function()
                    seat.CFrame = CFrame.new(seat.Position.X, seat.Position.Y - 50000, seat.Position.Z)
                    seat.AssemblyLinearVelocity = Vector3.new(0, -9e7, 0)
                end)
                TRun.Heartbeat:Wait()
            end
        end

        local target = TPlayers:FindFirstChild(targetName)
        if not target then return end

        local myChar = TLP.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if not (myRoot and myHum) then return end

        local SafeSpot = myRoot.CFrame

        task.spawn(function()
            local seatables = RG_FindSeatables(target)
            for _, seat in ipairs(seatables) do
                task.spawn(function() RG_VoidSeatable(seat) end)
                task.wait(0.02)
            end

            local tChar = target.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum  = tChar and tChar:FindFirstChildOfClass("Humanoid")
            if not (tRoot and tHum) then
                pcall(function()
                    myRoot.CFrame = SafeSpot
                    myRoot.AssemblyLinearVelocity = Vector3.zero
                    myRoot.AssemblyAngularVelocity = Vector3.zero
                end)
                return
            end

            pcall(function()
                myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end)

            local grabDeadline = tick() + GRAB_TIME
            while tick() < grabDeadline do
                if not target.Parent or not target.Character then break end
                local tCharNow = target.Character
                local tRootNow = tCharNow and tCharNow:FindFirstChild("HumanoidRootPart")
                local tHeadNow = tCharNow and tCharNow:FindFirstChild("Head")
                if not tRootNow then break end

                pcall(function()
                    TSetNetOwner:FireServer(tRootNow, tRootNow.CFrame)
                    if tHeadNow then TSetNetOwner:FireServer(tHeadNow, tHeadNow.CFrame) end
                    if StrongAntiLine then
                        TDestroyLine:FireServer(tRootNow)
                        if tHeadNow then TDestroyLine:FireServer(tHeadNow) end
                    end
                end)

                if OK_WeOwnIt(tRootNow) then
                    pcall(function()
                        tRootNow.AssemblyLinearVelocity = Vector3.zero
                        tRootNow.AssemblyAngularVelocity = Vector3.zero
                    end)
                    if tHum and tHum.PlatformStand ~= true then
                        tHum.PlatformStand = true
                    end
                end

                TRun.Heartbeat:Wait()
            end

            pcall(function()
                local tCharNow = target.Character
                local tHumNow = tCharNow and tCharNow:FindFirstChildOfClass("Humanoid")
                if tHumNow then
                    tHumNow.PlatformStand = false
                    tHumNow.Sit = false
                end
            end)

            pcall(function()
                myRoot.CFrame = SafeSpot
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end)
        end)
    end

    local function TRemoveInvisibility(targetName)
        local target = TPlayers:FindFirstChild(targetName)
        if not target then return end
        local tChar = target.Character
        local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
        if not tHum then return end
        pcall(function() tHum.Health = 0 end)
    end

--/(method dispatch)
    TStartOwnershipKickForPlayer = function(plr, anchorGetter)
        if not plr or not plr.Parent then return end
        local name = plr.Name
        if OwnershipKickThread[name] then
            OwnershipKickRefs[name] = anchorGetter
            return
        end
        OwnershipKickActive[name] = true
        OwnershipKickRefs[name]   = anchorGetter
        TKickTargets[plr.UserId] = true
        OwnershipKickThread[name] = task.spawn(function()
            RunOwnershipKick(name, function()
                return OwnershipKickActive[name] == true
            end, function()
                local g = OwnershipKickRefs[name]
                if type(g) == "function" then return g() end
                if typeof(g) == "Vector3" then return g end
                return nil
            end)
            OwnershipKickActive[name] = nil
            OwnershipKickThread[name] = nil
            OwnershipKickRefs[name]   = nil
            CleanupPalletFor(name)
            CleanupBodiesFor(name)
        end)
        TRegisterThread(OwnershipKickThread[name])
    end

    TApplyToPlayer = function(plr, anchorPos)
        if not plr or not plr.Parent then return end
        local name = plr.Name
        if TMethodSelected("Kick") then TStartOwnershipKickForPlayer(plr, anchorPos) end
        if TMethodSelected("Void") then TVoidTarget(name) end
        if TMethodSelected("Kill") then TKillTarget(name) end
        if TMethodSelected("Bring") then TBringTarget(name) end
        if TMethodSelected("Destroy Food") then TDestroyFood(name) end
        if TMethodSelected("Remove Gucci") then TRemoveGucci(name) end
        if TMethodSelected("Remove Invisibility") then TRemoveInvisibility(name) end
    end

--/(loop runner)
    task.spawn(function()
        while not Library.Unloaded do
            if LoopPlayer then
                local targets = TGetSelectedList()
                for i, plr in ipairs(targets) do
                    if plr and plr.Parent then
                        local getAnchor = makeAnchorGetter(i, #targets)
                        if TMethodSelected("Kick") then
                            TStartOwnershipKickForPlayer(plr, getAnchor)
                        end
                        TApplyToPlayer(plr, getAnchor())
                    end
                end
            end
            if LoopServer then
                local all = {}
                for _, plr in ipairs(TPlayers:GetPlayers()) do
                    if plr ~= TLP and plr.Character and plr.Character:FindFirstChild("Humanoid") then
                        table.insert(all, plr)
                    end
                end
                for i, plr in ipairs(all) do
                    if plr and plr.Parent then
                        local getAnchor = makeAnchorGetter(i, #all)
                        if TMethodSelected("Kick") then
                            TStartOwnershipKickForPlayer(plr, getAnchor)
                        end
                        TApplyToPlayer(plr, getAnchor())
                    end
                end
            end
            task.wait(0.5)
        end
    end)

--/(loop snowball)
    local function RunLoopSnowball()
        local inv = TWS:FindFirstChild(TLP.Name .. "SpawnedInToys")
        while LoopSnowballActive do
            inv = TWS:FindFirstChild(TLP.Name .. "SpawnedInToys") or inv
            for _, plr in ipairs(TGetSelectedList()) do
                local tChar = plr.Character
                if tChar then
                    local torso = tChar:FindFirstChild("HumanoidRootPart") or tChar:FindFirstChild("Torso")
                    if torso then
                        local allow = RemoteBudget_Take(1)
                        if allow > 0 then
                            local offset = Vector3.new(
                                math.random(-5, 5) / 10,
                                math.random(-5, 5) / 10,
                                math.random(-5, 5) / 10
                            )
                            task.spawn(function()
                                pcall(function()
                                    TSpawnToy:InvokeServer("BallSnowball", torso.CFrame * CFrame.new(offset), Vector3.zero)
                                end)
                            end)
                        end
                        if inv then
                            for _, sb in ipairs(inv:GetChildren()) do
                                if sb.Name == "BallSnowball" then
                                    local part = sb:IsA("BasePart") and sb
                                        or (sb.PrimaryPart or sb:FindFirstChildWhichIsA("BasePart"))
                                    if part then
                                        pcall(function()
                                            part.CFrame = torso.CFrame
                                            part.AssemblyLinearVelocity = Vector3.zero
                                            part.AssemblyAngularVelocity = Vector3.zero
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            TRun.Heartbeat:Wait()
        end
    end

    function TStartLoopSnowball()
        if LoopSnowballThread then task.cancel(LoopSnowballThread) end
        LoopSnowballActive = true
        LoopSnowballThread = task.spawn(RunLoopSnowball)
        TRegisterThread(LoopSnowballThread)
        TAddCleanup(function() TStopLoopSnowball() end)
    end

    function TStopLoopSnowball()
        LoopSnowballActive = false
        if LoopSnowballThread then task.cancel(LoopSnowballThread) LoopSnowballThread = nil end
        local inv = TWS:FindFirstChild(TLP.Name .. "SpawnedInToys")
        if inv then
            for _, sb in ipairs(inv:GetChildren()) do
                if sb.Name == "BallSnowball" then
                    pcall(function() TDestroyToy:FireServer(sb) end)
                end
            end
        end
    end

--/(loop ragdoll)
    local function CleanupRagdoll()
        RagdollPallet = nil
        RagdollSoundPart = nil
    end

    local function RunLoopRagdoll()
        while LoopRagdollActive do
            for _, plr in ipairs(TGetSelectedList()) do
                local tChar = plr.Character
                local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                local tHead = tChar and tChar:FindFirstChild("Head")
                local tHum  = tChar and tChar:FindFirstChildOfClass("Humanoid")
                if tRoot and tHum and tHum.Health > 0 then
                    local allow = RemoteBudget_Take(1)
                    if allow > 0 then
                        pcall(function()
                            TSetNetOwner:FireServer(tRoot, tRoot.CFrame)
                            if tHead then TSetNetOwner:FireServer(tHead, tHead.CFrame) end
                        end)
                    end
                    if TCharEvents and TCharEvents:FindFirstChild("RagdollRemote") then
                        pcall(function()
                            TCharEvents.RagdollRemote:FireServer(tRoot, 1)
                            TCharEvents.RagdollRemote:FireServer(tRoot, 0)
                        end)
                    end
                end
            end
            TRun.Heartbeat:Wait()
        end
        CleanupRagdoll()
    end

    function TStartLoopRagdoll()
        if LoopRagdollThread then task.cancel(LoopRagdollThread) end
        LoopRagdollActive = true
        LoopRagdollThread = task.spawn(RunLoopRagdoll)
        TRegisterThread(LoopRagdollThread)
        TAddCleanup(function() TStopLoopRagdoll() end)
    end

    function TStopLoopRagdoll()
        LoopRagdollActive = false
        if LoopRagdollThread then
            pcall(function() task.cancel(LoopRagdollThread) end)
            LoopRagdollThread = nil
        end
        if RagdollPallet and RagdollPallet.Parent then
            pcall(function() TDestroyToy:FireServer(RagdollPallet) end)
        end
        CleanupRagdoll()
    end

--/(unstick aura)
    local function RunUnstickAura()
        while UnstickAuraActive do
            local myRoot = TGetMyHRP()
            if myRoot then
                for _, target in ipairs(TPlayers:GetPlayers()) do
                    if target ~= TLP then
                        local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                        if tRoot and (tRoot.Position - myRoot.Position).Magnitude <= UnstickRadius then
                            local inv = TWS:FindFirstChild(target.Name .. "SpawnedInToys")
                            if inv then
                                for _, toyName in ipairs({ "NinjaKunai", "NinjaShuriken", "AntiKick" }) do
                                    local toy = inv:FindFirstChild(toyName)
                                    if toy then
                                        local soundPart = toy:FindFirstChild("SoundPart")
                                        if soundPart then
                                            pcall(function() TSetNetOwner:FireServer(soundPart, soundPart.CFrame) end)
                                            if soundPart:FindFirstChild("PartOwner")
                                                and soundPart.PartOwner.Value == TLP.Name then
                                                soundPart.CFrame = CFrame.new(0, 100000, 0)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end

    function TStartUnstickAura()
        if UnstickAuraThread then task.cancel(UnstickAuraThread) end
        UnstickAuraActive = true
        UnstickAuraThread = task.spawn(RunUnstickAura)
        TRegisterThread(UnstickAuraThread)
        TAddCleanup(function() TStopUnstickAura() end)
    end

    function TStopUnstickAura()
        UnstickAuraActive = false
        if UnstickAuraThread then task.cancel(UnstickAuraThread) UnstickAuraThread = nil end
    end

--/(cleanup)
    Library:OnUnload(function()
        LoopPlayer = false
        LoopServer = false
        LineLagActive = false
        TStopAllOwnershipKicks()
        TStopLoopSnowball()
        TStopLoopRagdoll()
        TStopUnstickAura()
        TKillAllThreads()
        TDisconnectAll()
        for _, fn in ipairs(TCleanups) do pcall(fn) end
        TCleanups = {}
    end)

--/endTarget
end
