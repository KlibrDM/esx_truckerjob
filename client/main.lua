ESX = nil
local PlayerData              	= {}
local alldeliveries             = {}
local randomdelivery            = 1
local isTaken                   = 0
local isDelivered               = 0
local currentZone               = ''
local LastZone                  = ''
local CurrentAction             = nil
local CurrentActionMsg          = ''
local CurrentActionData         = {}
local actualZone                = '' -- This variable is basically a duplicate of currentZone, sorry, I was stuck on something.
local truck	                    = 0
local trailer                   = 0
local deliveryblip

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
  PlayerData.job = job
end)


function SpawnTruck()
  --Delete old stuff. Variables already declared so no need to worry about it even if it's the first time starting the job
  ClearAreaOfVehicles(Config.VehicleSpawnPoint.Pos.x, Config.VehicleSpawnPoint.Pos.y, Config.VehicleSpawnPoint.Pos.z, 50.0, false, false, false, false, false)
  SetEntityAsNoLongerNeeded(trailer)
  DeleteVehicle(trailer)
  SetEntityAsNoLongerNeeded(truck)
  DeleteVehicle(truck)
  RemoveBlip(deliveryblip)
  
  --Spawn Truck
  local vehiclehash = GetHashKey(Config.Truck)
  RequestModel(vehiclehash)
  while not HasModelLoaded(vehiclehash) do
    RequestModel(vehiclehash)
    Citizen.Wait(0)
  end
  truck = CreateVehicle(vehiclehash, Config.VehicleSpawnPoint.Pos.x, Config.VehicleSpawnPoint.Pos.y, Config.VehicleSpawnPoint.Pos.z, 0.0, true, false)
  SetEntityAsMissionEntity(truck, true, true) --Not completely sure if this works, but it's supposed to make the engine not delete this vehicle even if out of player area
  
  --Spawn Trailer
  local trailerhash = GetHashKey(Config.Trailer)
  RequestModel(trailerhash)
  while not HasModelLoaded(trailerhash) do
    RequestModel(trailerhash)
    Citizen.Wait(0)
  end
  trailer = CreateVehicle(trailerhash, Config.TrailerSpawnPoint.Pos.x, Config.TrailerSpawnPoint.Pos.y, Config.TrailerSpawnPoint.Pos.z, 0.0, true, false)
  SetEntityAsMissionEntity(trailer, true, true) --Same as above, not completely sure if it works
  
  AttachVehicleToTrailer(truck, trailer, 1.1) --3rd parameter is the radius, if you changed the spawn locations for the truck and trailer, there might be a chance that you will have to change the radius too
  
  TaskWarpPedIntoVehicle(GetPlayerPed(-1), truck, -1) --Teleport the player into the truck, last parameter is the seat
  
  --Set delivery zone
  --This should probably be done outside of this function, but if it ain't broke, don't fix it.
  local deliveryids = 1
  for k,v in pairs(Config.Delivery) do
    table.insert(alldeliveries, {
        id = deliveryids,
        posx = v.Pos.x,
        posy = v.Pos.y,
        posz = v.Pos.z,
        payment = v.Payment,
    })
    deliveryids = deliveryids + 1  
  end
  randomdelivery = math.random(1,#alldeliveries)
  
  --Add the blip on the map
  deliveryblip = AddBlipForCoord(alldeliveries[randomdelivery].posx, alldeliveries[randomdelivery].posy, alldeliveries[randomdelivery].posz)
  SetBlipSprite(deliveryblip, 304)
  SetBlipDisplay(deliveryblip, 4)
  SetBlipScale(deliveryblip, 1.0)
  SetBlipColour(deliveryblip, 5)
  SetBlipAsShortRange(deliveryblip, true)
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString("Delivery point")
  EndTextCommandSetBlipName(deliveryblip)
  
  SetBlipRoute(deliveryblip, true) --Add the route to the blip
  
  --For delivery blip
  isTaken = 1
  
  --For delivery blip
  isDelivered = 0
end

function FinishDelivery()
  if IsVehicleAttachedToTrailer(truck) and (GetVehiclePedIsIn(GetPlayerPed(-1), false) == truck) then
    --Delete trailer but we leave him with the truck so he can go back
    DeleteVehicle(trailer)

    --Remove delivery zone
    RemoveBlip(deliveryblip)

    --Pay the poor fella
    TriggerServerEvent('esx_truckerjob:pay', alldeliveries[randomdelivery].payment)

    --For delivery blip
    isTaken = 0

    --For delivery blip
    isDelivered = 1
  else
	  TriggerEvent('esx:showNotification', "You have to use the trailer that was provided for you.")
  end
end

function AbortDelivery()
    --Delete trailer
    SetEntityAsNoLongerNeeded(trailer)
    DeleteVehicle(trailer)
	  SetEntityAsNoLongerNeeded(truck)
    DeleteVehicle(truck)

    --Remove delivery zone
    RemoveBlip(deliveryblip)

    --For delivery blip
    isTaken = 0

    --For delivery blip
    isDelivered = 1
	
end

AddEventHandler('esx_truckerjob:hasEnteredMarker', function(zone)
  if actualZone == 'menutrucker' then
    CurrentAction     = 'trucker_menu'
    CurrentActionMsg  = 'Press ~INPUT_CONTEXT~ to go on a mission'
    CurrentActionData = {zone = zone}
  elseif actualZone == 'delivered' then
    CurrentAction     = 'delivered_menu'
    CurrentActionMsg  = 'Press ~INPUT_CONTEXT~ for delivery'
    CurrentActionData = {zone = zone}
  elseif actualZone == 'abort' then
	  CurrentAction     = 'abort_menu'
    CurrentActionMsg  = 'Press ~INPUT_CONTEXT~ to abort mission'
    CurrentActionData = {zone = zone}
  end
end)

AddEventHandler('esx_truckerjob:hasExitedMarker', function(zone)
	CurrentAction = nil
	ESX.UI.Menu.CloseAll()
end)

-- Enter / Exit marker events
Citizen.CreateThread(function()
  while true do
		Wait(0)
		local coords      = GetEntityCoords(GetPlayerPed(-1))
		local isInMarker  = false
		local currentZone = nil
      
		if(GetDistanceBetweenCoords(coords, Config.Zones.VehicleSpawner.Pos.x, Config.Zones.VehicleSpawner.Pos.y, Config.Zones.VehicleSpawner.Pos.z, true) < 3) and PlayerData.job ~= nil and PlayerData.job.name == 'trucker' then
			isInMarker  = true
			currentZone = 'menutrucker'
			LastZone    = 'menutrucker'
			actualZone  = 'menutrucker'
		end
      
		if isTaken == 1 and (GetDistanceBetweenCoords(coords, alldeliveries[randomdelivery].posx, alldeliveries[randomdelivery].posy, alldeliveries[randomdelivery].posz, true) < 3) then
			isInMarker  = true
			currentZone = 'delivered'
			LastZone    = 'delivered'
			actualZone  = 'delivered'
		end
		
		if isTaken == 1 and (GetDistanceBetweenCoords(coords, Config.Zones.MissionAbort.Pos.x, Config.Zones.MissionAbort.Pos.y, Config.Zones.MissionAbort.Pos.z, true) < 3) then
			isInMarker  = true
			currentZone = 'abort'
			LastZone    = 'abort'
			actualZone  = 'abort'
		end
        
		if isInMarker and not HasAlreadyEnteredMarker then
			HasAlreadyEnteredMarker = true
			TriggerEvent('esx_truckerjob:hasEnteredMarker', currentZone)
		end
		if not isInMarker and HasAlreadyEnteredMarker then
			HasAlreadyEnteredMarker = false
			TriggerEvent('esx_truckerjob:hasExitedMarker', LastZone)
		end
	end
end)

-- Key Controls
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    if CurrentAction ~= nil then
      SetTextComponentFormat('STRING')
      AddTextComponentString(CurrentActionMsg)
      DisplayHelpTextFromStringLabel(0, 0, 1, -1)
      if IsControlJustReleased(0, 38) then
        if CurrentAction == 'trucker_menu' then
          SpawnTruck()
        elseif CurrentAction == 'delivered_menu' then
          FinishDelivery()
		    elseif CurrentAction == 'abort_menu' then
		      AbortDelivery()
        end
        CurrentAction = nil
      end
    end
  end
end)

-- Display markers
Citizen.CreateThread(function()
  while true do
    Wait(0)
    local coords = GetEntityCoords(GetPlayerPed(-1))
    for k,v in pairs(Config.Zones) do
			if (v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) and PlayerData.job ~= nil and PlayerData.job.name == 'trucker' then
				DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
			end
		end
  end
end)

-- Display markers for delivery place
Citizen.CreateThread(function()
  while true do
    Wait(0)
    if isTaken == 1 and isDelivered == 0 then
    local coords = GetEntityCoords(GetPlayerPed(-1))
      v = alldeliveries[randomdelivery]
	    if (GetDistanceBetweenCoords(coords, v.posx, v.posy, v.posz, true) < Config.DrawDistance) then
				DrawMarker(1, v.posx, v.posy, v.posz, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 5.0, 5.0, 1.0, 204, 204, 0, 100, false, false, 2, false, false, false, false)
	    end
    end
  end
end)

-- Create Blips for Truck Spawner
Citizen.CreateThread(function()
    info = Config.Zones.VehicleSpawner
    info.blip = AddBlipForCoord(info.Pos.x, info.Pos.y, info.Pos.z)
    SetBlipSprite(info.blip, info.Id)
    SetBlipDisplay(info.blip, 4)
    SetBlipScale(info.blip, 1.0)
    SetBlipColour(info.blip, info.Colour)
    SetBlipAsShortRange(info.blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(info.Title)
    EndTextCommandSetBlipName(info.blip)
end)
