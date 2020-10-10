class 'SharpshooterServer'

function SharpshooterServer:__init()
    print('Hello world from Sharpshooter!')
 
    self:RegisterVars()
    self:RegisterEvents()
end

function SharpshooterServer:RegisterEvents()
    Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
    Events:Subscribe('Level:Loaded', self, self.OnLevelLoaded)
    Events:Subscribe('Player:Respawn', self, self.Respawn)
    Events:Subscribe('Server:RoundReset', self, self.StartTimer)
    Events:Subscribe('Engine:Update',self, self.EngineTick)
end

function SharpshooterServer:RegisterVars()
    self.weaponTable = {}
    self.unlockTables = {}
    self.PlayerSpawn = false

    --All possible weapons and sights
    self.weaponNameTable = {"M39EBR","PP2000","MagpulPDR","P90","KH2002","PP-19","AEK971","870","M98B","Jackhammer","A91","Pecheneg","SAIGA_20K","M27IAR","M16A4","HK417","ACR","M4A1","SCAR-H","SCAR-L","M240","QBB-95","JNG90","UMP45","FAMAS","SteyrAug","L85A2","USAS-12","SVD","HK53","MK11","SPAS12","QBU-88_Sniper","QBZ-95B","G3A3","F2000","DAO-12","MTAR","Type88","SV98","M16_Burst","SKS","MP7","RPK-74M","M60","AN94","AK74M","SG553LB","G36C","M1014","MP5K","M40A5","ASVal","AKS74u","L96","LSAT","M416","M249","M4","L86","MG36","M93R","Taurus44_Scoped","M9_Silenced","M9_TacticalLight","MP412Rex","Taurus44","Glock17","M1911_Silenced","M1911_Tactical","MP443_Silenced","M9","Glock18","Glock17_Silenced","M1911","MP443_TacticalLight","M1911_Lit","MP443","Glock18_Silenced","SMAW","Crossbow_Scoped_Cobra","M26Mass","M320_HE","M320_SHG","Crossbow_Scoped_RifleScope","RPG7","M26Mass_Flechette","M26Mass_Slug"}
    print(self.weaponNameTable)
    self.secondaryTable = {}
    self.thirdSlotTable = {}
    self.sightTable = {"BallisticScope","scope","Scope","PKA","IRNV","NoOptics","PSO-1","PK-AS","PKS-07","Acog","ACOG","M145","Kobra","EOTech","Eotech","RX01","RifleScope"}
    self.barrelAttachmentsTable = {"ExtendedMag","TargetPointer","HeavyBarrel","Flashlight","Flashsuppressor","Suppressor","FlashSuppressor","Silencer","Barrel"}
    self.railAttachmentsTable = {"StraightPull","Bipod","Foregrip","NoSecondaryRail"}
    self.shotgunRoundsTable = {"12gBuckshot","Slug","Flechette","Frag"}

    self.currentWeapon = nil
    self.currentWeaponAttachments = {}

    self.TimeWaited = 0 --Both used in the main Engine:Update Timer
    self.SecondsWaited = 0
end


-- Store the reference of all the SoldierWeaponUnlockAssets that get loaded
function SharpshooterServer:OnPartitionLoaded(partition)
    local instances = partition.instances

    for _, instance in pairs(instances) do
        
		if instance:Is('SoldierWeaponUnlockAsset') then
			
			local weaponUnlockAsset = SoldierWeaponUnlockAsset(instance)
		
			-- Weapons/SAIGA20K/U_SAIGA_20K --> SAIGA_20K
			local weaponName = weaponUnlockAsset.name:match("/U_.+"):sub(4)
			self.weaponTable[weaponName] = weaponUnlockAsset
		end
    end
end

-- Once the everything is loaded, store the UnlockAssets in each CustomizationUnlockParts array (each array is an attachment/sight/camo slot).
function SharpshooterServer:OnLevelLoaded()

	for weaponName, weaponUnlockAsset in pairs(self.weaponTable) do
	
		if SoldierWeaponData(SoldierWeaponBlueprint(weaponUnlockAsset.weapon).object).customization ~= nil then -- Gadgets dont have customization
		
			self.unlockTables[weaponName] = {}
			
			local customizationUnlockParts = CustomizationTable(VeniceSoldierWeaponCustomizationAsset(SoldierWeaponData(SoldierWeaponBlueprint(weaponUnlockAsset.weapon).object).customization).customization).unlockParts
			
			for _, unlockParts in pairs(customizationUnlockParts) do
			
				for _, asset in pairs(unlockParts.selectableUnlocks) do
				
					-- Weapons/AN94/U_AN94_Acog --> Acog
					local unlockAssetName = asset.debugUnlockId:gsub("U_.+_","")

					self.unlockTables[weaponName][unlockAssetName] = asset
				end
            end
		end
    end
    self:GenerateWeapon()
    self.SecondsWaited = -15 --Hacking work around for timer starting too soon, timer starts before server is even accepting connections, this resets it to -15 when the server reloads
end


function SharpshooterServer:Respawn(player)
    print("On Spawn Firing")
    if player.soldier == nil then
        print("Soldier didn't exist")
    end

    local timeDelayed = 0.0
    self.PlayerSpawn = true
    Events:Subscribe('Engine:Update', function(deltaTime) 
        timeDelayed = timeDelayed + deltaTime
        if self.PlayerSpawn == true then
            if timeDelayed >= 0.09 then
                print("Delayed spawn")
                self:ReplaceWeapons(player)
                timeDelayed = 0
                self.PlayerSpawn = false
            end
        end
    end)
end


function SharpshooterServer:GenerateWeapon()
    math.randomseed(SharedUtils:GetTimeMS())
    local currentWeaponName = self.weaponNameTable[math.random(#self.weaponNameTable)]
    self.currentWeapon = self.weaponTable[currentWeaponName]
    local possibleSights = {}
    local possibleBarrels = {}
    local possibleRails = {}
    local possibleAmmos = {}
    
    if self.unlockTables[currentWeaponName] ~=nil then
        for i=1, #self.sightTable do
            if self.unlockTables[currentWeaponName][self.sightTable[i]] ~= nil then
                table.insert(possibleSights, self.unlockTables[currentWeaponName][self.sightTable[i]])
            end
        end
    
        for i=1, #self.barrelAttachmentsTable do
            if self.unlockTables[currentWeaponName][self.barrelAttachmentsTable[i]] ~= nil then
                table.insert(possibleBarrels, self.unlockTables[currentWeaponName][self.barrelAttachmentsTable[i]])
            end
        end
    
        for i=1, #self.railAttachmentsTable do
            if self.unlockTables[currentWeaponName][self.railAttachmentsTable[i]] ~= nil then
                table.insert(possibleRails, self.unlockTables[currentWeaponName][self.railAttachmentsTable[i]])
            end
        end
    
        for i=1, #self.shotgunRoundsTable do
            if self.unlockTables[currentWeaponName][self.shotgunRoundsTable[i]] ~= nil then
                table.insert(possibleAmmos, self.unlockTables[currentWeaponName][self.shotgunRoundsTable[i]])
            end
        end
        self.currentWeaponAttachments = {possibleSights[math.random(#possibleSights)],possibleBarrels[math.random(#possibleBarrels)],possibleAmmos[math.random(#possibleAmmos)],possibleRails[math.random(#possibleRails)]}    
    else
        self.currentWeaponAttachments = {}
    end
end


function SharpshooterServer:ReplaceWeapons(player)

    -- Remove all of the players customizations
    local noWeaponsCustomizeSoldier = CustomizeSoldierData()
    noWeaponsCustomizeSoldier.removeAllExistingWeapons = true
    player.soldier:ApplyCustomization(noWeaponsCustomizeSoldier)
    player:SelectWeapon(WeaponSlot.WeaponSlot_0, self.currentWeapon, self.currentWeaponAttachments)
    player:SelectWeapon(WeaponSlot.WeaponSlot_7, self.weaponTable["Knife_Razor"], {})

    -- Insert weapon logic here
end

function SharpshooterServer:ReplaceAllWeapons()
    players = PlayerManager:GetPlayers()
    print(players)
    for _, player in pairs(players) do
        self:ReplaceWeapons(player)
    end
end


function SharpshooterServer:EngineTick(deltaTime)
    self.TimeWaited = self.TimeWaited + deltaTime
    if self.TimeWaited >= 1 then
        print(self.SecondsWaited)
        if self.SecondsWaited >= 15 then
            print("45 second loop")
            self.SecondsWaited = 0
            self:GenerateWeapon()
            self:ReplaceAllWeapons()
            --Spawn new weapon
            --Hand out new weapon
        else
            print("1 second loop")
            self.SecondsWaited = self.SecondsWaited + 1
            self.TimeWaited = 0
            -- Update Client Timer
        end
    end
end

function SharpshooterServer:StartTimer()
    self.SecondsWaited = 0
end

g_SharpshooterServer = SharpshooterServer()