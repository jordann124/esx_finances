ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('esx_billing:sendBill')
AddEventHandler('esx_billing:sendBill', function(playerId, sharedAccountName, label, amount)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local xTarget = ESX.GetPlayerFromId(playerId)

	TriggerEvent('esx_addonaccount:getSharedAccount', sharedAccountName, function(account)

		if amount < 0 then
			print('esx_billing: ' .. GetPlayerName(_source) .. ' tentou enviar uma Fatura negativa!')
		elseif account == nil then

			if xTarget ~= nil then
				MySQL.Async.execute(
					'INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (@identifier, @sender, @target_type, @target, @label, @amount)',
					{
						['@identifier']  = xTarget.identifier,
						['@sender']      = xPlayer.identifier,
						['@target_type'] = 'player',
						['@target']      = xPlayer.identifier,
						['@label']       = label,
						['@amount']      = amount
					},
					function(rowsChanged)
						TriggerClientEvent('esx:showNotification', xTarget.source, _U('received_invoice'))
					end
				)
			end

		else

			if xTarget ~= nil then
				MySQL.Async.execute(
					'INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (@identifier, @sender, @target_type, @target, @label, @amount)',
					{
						['@identifier']  = xTarget.identifier,
						['@sender']      = xPlayer.identifier,
						['@target_type'] = 'society',
						['@target']      = sharedAccountName,
						['@label']       = label,
						['@amount']      = amount
					},
					function(rowsChanged)
						TriggerClientEvent('esx:showNotification', xTarget.source, _U('received_invoice'))
					end
				)
			end

		end
	end)

end)

ESX.RegisterServerCallback('esx_billing:getBills', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll(
		'SELECT * FROM billing WHERE identifier = @identifier',
		{
			['@identifier'] = xPlayer.identifier
		},
		function(result)

			local bills = {}

			for i=1, #result, 1 do
				table.insert(bills, {
					id         = result[i].id,
					identifier = result[i].identifier,
					sender     = result[i].sender,
					targetType = result[i].target_type,
					target     = result[i].target,
					label      = result[i].label,
					amount     = result[i].amount
				})
			end

			cb(bills)

		end
	)

end)

ESX.RegisterServerCallback('esx_billing:getTargetBills', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	MySQL.Async.fetchAll(
		'SELECT * FROM billing WHERE identifier = @identifier',
		{
			['@identifier'] = xPlayer.identifier
		},
		function(result)

			local bills = {}

			for i=1, #result, 1 do
				table.insert(bills, {
					id         = result[i].id,
					identifier = result[i].identifier,
					sender     = result[i].sender,
					targetType = result[i].target_type,
					target     = result[i].target,
					label      = result[i].label,
					amount     = result[i].amount
				})
			end

			cb(bills)

		end
	)

end)


ESX.RegisterServerCallback('esx_billing:payBill', function(source, cb, id)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll(
		'SELECT * FROM billing WHERE id = @id',
		{
			['@id'] = id
		}, function(result)

			local sender     = result[1].sender
			local targetType = result[1].target_type
			local target     = result[1].target
			local amount     = result[1].amount

			local xTarget = ESX.GetPlayerFromIdentifier(sender)

			if targetType == 'player' then

				if xTarget ~= nil then

					if xPlayer.getMoney() >= amount then

						MySQL.Async.execute('DELETE from billing WHERE id = @id',
						{
							['@id'] = id
						}, function(rowsChanged)
							xPlayer.removeMoney(amount)
							xTarget.addMoney(amount)

							TriggerClientEvent('esx:showNotification', xPlayer.source, _U('paid_invoice', amount))
							TriggerClientEvent('esx:showNotification', xTarget.source, _U('received_payment', amount))
							if Config.EnableJobLogs == true then
								TriggerEvent('esx_joblogs:AddInLog', xTarget.job.name, 'paybill', xPlayer.name, xTarget.name, amount)
							end
							cb()
						end)

					elseif xPlayer.getBank() >= amount then

						MySQL.Async.execute('DELETE from billing WHERE id = @id',
						{
							['@id'] = id
						}, function(rowsChanged)
							xPlayer.removeAccountMoney('bank', amount)
							xTarget.addAccountMoney('bank', amount)

							TriggerClientEvent('esx:showNotification', xPlayer.source, _U('paid_invoice', amount))
							TriggerClientEvent('esx:showNotification', xTarget.source, _U('received_payment', amount))

							cb()
						end)

					else
						TriggerClientEvent('esx:showNotification', xTarget.source, _U('target_no_money'))
						TriggerClientEvent('esx:showNotification', xPlayer.source, _U('no_money'))

						cb()
					end

				else
					TriggerClientEvent('esx:showNotification', xPlayer.source, _U('player_not_online'))
					cb()
				end

			else

				TriggerEvent('esx_addonaccount:getSharedAccount', target, function(account)

					if xPlayer.getMoney() >= amount then

						MySQL.Async.execute('DELETE from billing WHERE id = @id',
						{
							['@id'] = id
						}, function(rowsChanged)
							xPlayer.removeMoney(amount)
							account.addMoney(amount)

							TriggerClientEvent('esx:showNotification', xPlayer.source, _U('paid_invoice', amount))
								if Config.EnableJobLogs == true then
								local TargetJob = ""
									if target == "society_ambulance" then
										TargetJob = "ambulance"
									elseif target == "society_concess" then
										TargetJob = "concess"
									elseif target == "society_mecano" then
										TargetJob = "mecano"									
									elseif target == "society_police" then
										TargetJob = "police"
									elseif target == "society_gnr" then
										TargetJob = "gnr"
									elseif target == "society_pj" then
										TargetJob = "pj"
									elseif target == "society_taxi" then
										TargetJob = "taxi"
									elseif target == "society_uber" then
										TargetJob = "uber"
									end
									TriggerEvent('esx_joblogs:AddInLog', TargetJob, 'paybill', xPlayer.name, xTarget, amount)
								end
							
							if xTarget ~= nil then
								TriggerClientEvent('esx:showNotification', xTarget.source, _U('received_payment', amount))
							end

							cb()
						end)

					elseif xPlayer.getBank() >= amount then

						MySQL.Async.execute('DELETE from billing WHERE id = @id',
						{
							['@id'] = id
						}, function(rowsChanged)
							xPlayer.removeAccountMoney('bank', amount)
							account.addMoney(amount)

							TriggerClientEvent('esx:showNotification', xPlayer.source, _U('paid_invoice', amount))
								if Config.EnableJobLogs == true then
								local TargetJob = ""
									if target == "society_ambulance" then
										TargetJob = "ambulance"
									elseif target == "society_concess" then
										TargetJob = "concess"
									elseif target == "society_mecano" then
										TargetJob = "mecano"									
									elseif target == "society_police" then
										TargetJob = "police"									
									elseif target == "society_gnr" then
										TargetJob = "gnr"
									elseif target == "society_pj" then
										TargetJob = "pj"
									elseif target == "society_taxi" then
										TargetJob = "taxi"
									elseif target == "society_uber" then
										TargetJob = "uber"
									end
									TriggerEvent('esx_joblogs:AddInLog', TargetJob, 'paybill', xPlayer.name, xTarget, amount)
								end
							if xTarget ~= nil then
								TriggerClientEvent('esx:showNotification', xTarget.source, _U('received_payment', amount))
							end

							cb()
						end)

					else
						TriggerClientEvent('esx:showNotification', xPlayer.source, _U('no_money'))

						if xTarget ~= nil then
							TriggerClientEvent('esx:showNotification', xTarget.source, _U('target_no_money'))
						end

						cb()
					end
				end)

			end

		end
	)

end)